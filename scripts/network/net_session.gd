class_name NetSession
extends Node
## Transporte da partida (Adendo 06): ENet + API de RPC de alto nível do Godot. O MESMO nó vive nos dois lados
## (o caminho e os RPCs precisam coincidir): host() o torna o servidor autoritário (MatchServer dentro dele),
## connect_to() o torna cliente. O cliente se apresenta (hello), manda direção (submit); o servidor devolve boas-vindas
## e snapshots. Reconexão (cap. 04 parte 04): quem perde o servidor tenta voltar sozinho com o token da sessão, até a
## janela que o SERVIDOR definiu; o servidor autentica e devolve o estado completo.

signal connected                                   # cliente: o servidor aceitou a conexão
signal disconnected                                # cliente: perdeu o servidor ou foi recusado
signal welcome_received(civilization_id: int)      # cliente: qual civilização é a minha
signal snapshot_received(snapshot: Dictionary)     # cliente: estado real da partida
signal reconnected(state: Dictionary)              # cliente: voltei à partida com o estado completo
signal reconnect_failed(reason: String)            # cliente: desisti (janela esgotada ou o servidor recusou a sessão)
signal resynced_with_server(state: Dictionary)     # cliente: o servidor reenviou o estado oficial (dessincronização)

const SNAPSHOT_HZ := 20.0
const DIGEST_EVERY := 10   # snapshots entre dois relatos de hash do cliente (~0,5 s)

var match_server: MatchServer = null   # só no servidor
var predictor: RunnerPredictor = null  # só no cliente: o corredor do próprio jogador, previsto (nasce no 1º snapshot)
var interpolator: RemoteInterpolator = null   # só no cliente: os OUTROS corredores, suavizados (nasce no 1º snapshot)
## Cliente: hash do MEU mapa de territórios como estava no último snapshot recebido. Vazio = o detector de
## dessincronia fica desligado (o cliente ainda não tem mapa próprio para conferir).
var local_digest := Callable()
var my_civ := 0
var last_snapshot: Dictionary = {}
var last_full_state: Dictionary = {}   # cliente: o que o servidor mandou na última volta
var session_token := ""                # cliente: prova de que a sessão é minha (o servidor renova a cada volta)
var reconnect_window := 20.0           # cliente: segundos de tentativa; o valor vem do servidor (welcome)
var reconnect_interval := 1.0          # cliente: pausa entre tentativas

var _seq := 0
var _net_time := 0.0        # relógio local do transporte: base da interpolação dos remotos
var _digest_count := 0
var _snapshot_clock := 0.0
var _address := ""
var _port := 0
var _closed := false        # fechei de propósito: não há o que reconectar
var _reconnecting := false
var _attempting := false    # uma tentativa de conexão está em andamento
var _elapsed := 0.0
var _retry_clock := 0.0


func host(port: int, max_clients := 5) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	match_server = MatchServer.new()
	add_child(match_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK


func connect_to(address: String, port: int) -> Error:
	_address = address
	_port = port
	_closed = false
	return _open()


func close() -> void:
	_closed = true
	_reconnecting = false
	multiplayer.multiplayer_peer = null


func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Cliente: pede ao servidor para virar e já prevê o quadro localmente (DD-044). `dt` = duração do quadro de tela.
## Devolve o número do comando (a predição guarda o que o servidor ainda não confirmou). Fora do ar: não faz nada
## (o corredor segue reto no servidor até a volta).
func send_steer(value: float, dt: float) -> int:
	if not is_online():
		return _seq
	_seq += 1
	submit.rpc_id(1, {"type": "steer", "seq": _seq, "steer": value})
	if predictor != null:
		predictor.predict(_seq, value, dt)
	return _seq


## Cliente: "estou dessincronizado" (a tela não bate com o que o servidor diz). O servidor reenvia o estado oficial,
## no máximo 1 vez por intervalo; o excesso é ignorado.
func request_resync() -> void:
	if is_online():
		resync_request.rpc_id(1)


## Cliente: onde desenhar o corredor remoto `civ_id` agora ({pos, fwd}); {} se ainda não chegou nada dele.
func remote_pose(civ_id: int) -> Dictionary:
	return interpolator.sample(civ_id, _net_time) if interpolator != null else {}


func _process(delta: float) -> void:
	_net_time += delta
	if predictor != null:
		predictor.update_visual(delta)
	if _reconnecting:
		_try_reconnect(delta)
	if match_server == null or multiplayer.multiplayer_peer == null:
		return
	_snapshot_clock += delta
	if _snapshot_clock < 1.0 / SNAPSHOT_HZ:
		return
	_snapshot_clock = 0.0
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	for peer_id in multiplayer.get_peers():
		var link := enet.get_peer(peer_id)   # quem já está fechando a conexão não recebe mais nada
		if match_server.has_peer(peer_id) and link != null and link.get_state() == ENetPacketPeer.STATE_CONNECTED:
			deliver.rpc_id(peer_id, match_server.snapshot_for(peer_id))


func _open() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(_address, _port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_attempting = true
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.server_disconnected.connect(_on_lost)
		multiplayer.connection_failed.connect(_on_failed)
	return OK


func _on_connected() -> void:
	_attempting = false
	connected.emit()
	hello.rpc_id(1, session_token)   # "" = jogador novo; com token = quem quer voltar


func _on_lost() -> void:
	_attempting = false
	if _reconnecting:
		return   # uma tentativa de volta foi encerrada: a próxima sai do relógio
	disconnected.emit()
	if session_token != "" and not _closed:
		_reconnecting = true
		_elapsed = 0.0
		_retry_clock = 0.0   # DD-047: volta rápido, a 1ª tentativa é já


func _on_failed() -> void:
	_attempting = false
	if not _reconnecting:
		disconnected.emit()


func _try_reconnect(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= reconnect_window:
		_give_up("janela_esgotada")
		return
	if _attempting:
		return
	_retry_clock -= delta
	if _retry_clock <= 0.0:
		_retry_clock = reconnect_interval
		_open()


func _give_up(reason: String) -> void:
	_reconnecting = false
	_attempting = false
	multiplayer.multiplayer_peer = null
	reconnect_failed.emit(reason)


# Fecha a conexão DEPOIS de entregar o que já está na fila (disconnect_peer descartaria o motivo da recusa).
func _kick(peer_id: int) -> void:
	var link := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id)
	if link != null:
		link.peer_disconnect_later()


func _on_peer_disconnected(peer_id: int) -> void:
	match_server.peer_left(peer_id)


# Servidor: a 1ª mensagem de quem conecta. Variant, não String: o que chega da rede nunca é confiável.
@rpc("any_peer", "call_remote", "reliable")
func hello(token: Variant) -> void:
	if match_server == null:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if match_server.has_peer(peer_id):
		match_server.net_log.add(0, "hello_repetido", "aviso", "peer %d ignorado" % peer_id)
		return
	if typeof(token) == TYPE_STRING and token == "":   # jogador novo
		var civ := match_server.free_civilization()
		if civ == 0 or not match_server.join(peer_id, civ):
			match_server.net_log.add(0, "partida_cheia", "aviso", "peer %d recusado" % peer_id)
			_kick(peer_id)
			return
		welcome.rpc_id(peer_id, civ, match_server.token_of(civ), match_server.reconnect_window)
		return
	var result := match_server.resume(peer_id, token)
	if not result.ok:
		refused.rpc_id(peer_id, result.reason)
		_kick(peer_id)
		return
	resumed.rpc_id(peer_id, result.state)


# Variant, não Dictionary: o que chega da rede nunca é confiável, quem valida é o NetProtocol.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit(msg: Variant) -> void:
	if match_server != null:
		match_server.handle_command(multiplayer.get_remote_sender_id(), msg)


@rpc("authority", "call_remote", "reliable")
func welcome(civilization_id: int, token: String, window: float) -> void:
	my_civ = civilization_id
	session_token = token
	reconnect_window = window
	welcome_received.emit(civilization_id)


# O servidor não aceitou a sessão. "sessao_ativa" = a conexão antiga ainda não caiu para ele: tento de novo.
@rpc("authority", "call_remote", "reliable")
func refused(reason: String) -> void:
	if reason == "sessao_ativa" and _reconnecting:
		return
	_give_up(reason)


# Voltei: o servidor mandou o estado completo (planeta, territórios, relógio, vidas, bônus, posição oficial).
@rpc("authority", "call_remote", "reliable")
func resumed(state: Dictionary) -> void:
	_reconnecting = false
	_seq = 0
	_adopt(state)
	reconnected.emit(state)


# Servidor: o cliente se diz dessincronizado. Quem decide se atende (e quando) é o MatchServer.
@rpc("any_peer", "call_remote", "reliable")
func resync_request() -> void:
	if match_server == null:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var result := match_server.resync(peer_id)
	if result.ok:
		resynced.rpc_id(peer_id, result.state)


# O estado oficial substitui o que o cliente achava (a numeração dos comandos continua: a sessão é a mesma).
@rpc("authority", "call_remote", "reliable")
func resynced(state: Dictionary) -> void:
	_adopt(state)
	resynced_with_server.emit(state)


@rpc("authority", "call_remote", "unreliable_ordered")
func deliver(snapshot: Dictionary) -> void:
	last_snapshot = snapshot
	_reconcile(snapshot)
	_feed_remotes(snapshot)
	_digest_count += 1
	if local_digest.is_valid() and _digest_count % DIGEST_EVERY == 0:
		digest_report.rpc_id(1, snapshot.tick, local_digest.call())
	snapshot_received.emit(snapshot)


# Servidor: o cliente relata o hash do mapa dele num tick. Divergiu => o estado oficial volta pelo mesmo caminho do
# pedido manual (e com o mesmo limite de frequência). Variant: o que chega da rede nunca é confiável.
@rpc("any_peer", "call_remote", "reliable")
func digest_report(tick: Variant, digest: Variant) -> void:
	if match_server == null:
		return
	var result := match_server.verify_digest(multiplayer.get_remote_sender_id(), tick, digest)
	if result.has("state"):
		resynced.rpc_id(multiplayer.get_remote_sender_id(), result.state)


func _adopt(state: Dictionary) -> void:
	my_civ = state.civ
	session_token = state.token
	reconnect_window = state.window
	last_full_state = state
	last_snapshot = state
	predictor = null   # recomeça do estado oficial
	interpolator = null
	_reconcile(state)
	_feed_remotes(state)


# Os corredores dos outros entram no suavizador; o meu é previsto, não interpolado.
func _feed_remotes(snapshot: Dictionary) -> void:
	if Services.planet == null:
		return
	if interpolator == null:
		interpolator = RemoteInterpolator.new(Services.planet)
	for p: Dictionary in snapshot.players:
		if p.id != my_civ:
			interpolator.push(p.id, _net_time, p.pos, p.fwd)


# O estado oficial do meu corredor corrige a predição (nunca o contrário).
func _reconcile(snapshot: Dictionary) -> void:
	var mine: Array = snapshot.players.filter(func(p: Dictionary) -> bool: return p.id == my_civ)
	if mine.is_empty() or Services.planet == null:
		return
	if predictor == null:
		predictor = RunnerPredictor.new(Services.planet)
		predictor.reset(mine[0].pos, mine[0].fwd)
		return
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.get_peer(1) != null:
		predictor.latency = enet.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 2000.0
	predictor.reconcile(mine[0].pos, mine[0].fwd, snapshot.get("ack", -1))
