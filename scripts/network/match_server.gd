class_name MatchServer
extends Node
## O servidor da partida (DD-041..043): a ÚNICA autoridade. O cliente só envia comandos de direção
## (NetProtocol); o servidor valida, aplica ao corredor da civilização daquele jogador e devolve
## snapshots do estado real. Cliente nenhum cria território, tira vidas ou decide vencedor.
## Independe do transporte: handle_command() recebe um Dictionary, venha de ENet (Passo 25) ou de teste.

var net_log := NetLog.new()
var tick := 0
var reconnect_window := 20.0   # s que o servidor espera a volta de quem caiu; passou disso, o jogador é ELIMINADO (DD-048: quem manda é o servidor)

var _peers: Dictionary = {}       # peer_id -> sessão {civ, seq, steering, token, connected, wait, expired}
var _eliminated: Dictionary = {}  # civ_id -> true (quem o servidor viu cair; comandos dele são ignorados)


func _ready() -> void:
	EventBus.civilization_eliminated.connect(func(id: int): _eliminated[id] = true)


func _physics_process(_delta: float) -> void:
	tick += 1


# Quem caiu e não voltou dentro da janela perde a partida (a partida NUNCA para por causa dele).
func _process(delta: float) -> void:
	for session: Dictionary in _peers.values():
		if session.connected or session.expired:
			continue
		session.wait -= delta
		if session.wait <= 0.0:
			_expire(session)


## Entrega o corredor da civilização ao jogador remoto. Um jogador por civilização e vice-versa.
func join(peer_id: int, civilization_id: int) -> bool:
	var runner := _runner_of(civilization_id)
	if runner == null or _peers.has(peer_id) or peer_of(civilization_id) != 0:
		net_log.add(civilization_id, "join_recusado", "aviso", "peer %d ignorado" % peer_id)
		return false
	var driver := RemoteSteering.new()
	runner.use_steering(driver)
	_peers[peer_id] = {"civ": civilization_id, "seq": -1, "steering": driver, "token": _new_token(), "connected": true, "wait": 0.0, "expired": false}
	return true


## Primeira civilização com corredor em campo e sem jogador remoto (0 = partida cheia).
func free_civilization() -> int:
	var ids: Array = get_tree().get_nodes_in_group("runners").map(func(r: Node) -> int: return r.get_node("Civilization").id)
	ids.sort()
	for id: int in ids:
		if peer_of(id) == 0 and not _eliminated.has(id):
			return id
	return 0


func has_peer(peer_id: int) -> bool:
	return _peers.has(peer_id)


## A conexão do jogador caiu: o corredor segue em frente (sem volante, sem invulnerabilidade) e a sessão espera
## `reconnect_window` segundos pela volta. O fato fica registrado.
func peer_left(peer_id: int) -> void:
	var session: Dictionary = _peers.get(peer_id, {})
	if session.is_empty() or not session.connected:
		return
	session.steering.steer = 0.0
	session.connected = false
	if _eliminated.has(session.civ):
		session.expired = true   # já estava fora da partida: não há o que esperar
		net_log.add(session.civ, "peer_desconectado", "info", "jogador já eliminado")
		return
	session.wait = reconnect_window
	net_log.add(session.civ, "peer_desconectado", "aviso", "corredor segue reto; espera %.0f s pela volta" % reconnect_window)


## Quem voltou: autentica pelo token da sessão e devolve o ESTADO COMPLETO (DD-047). Nenhum login novo toma uma
## sessão ativa nem uma expirada; só quem tem o token da sessão em espera assume o corredor de volta.
## Devolve {ok, state} ou {ok: false, reason}; toda tentativa fica no registro.
func resume(peer_id: int, token: Variant) -> Dictionary:
	if _peers.has(peer_id):
		return _refuse(0, "peer_ja_vinculado", peer_id)
	var old_id := 0
	if typeof(token) == TYPE_STRING and token != "":
		for id: int in _peers:
			if _peers[id].token == token:
				old_id = id
	if old_id == 0:
		return _refuse(0, "token_invalido", peer_id)
	var session: Dictionary = _peers[old_id]
	if session.expired:
		return _refuse(session.civ, "sessao_expirada", peer_id)
	if session.connected:
		return _refuse(session.civ, "sessao_ativa", peer_id)
	var away: float = reconnect_window - session.wait
	_peers.erase(old_id)
	_peers[peer_id] = session
	session.connected = true
	session.seq = -1                 # a numeração dos comandos recomeça
	session.token = _new_token()     # token usado não vale de novo
	net_log.add(session.civ, "reconexao_aceita", "info", "voltou após %.1f s" % away)
	return {"ok": true, "state": full_state(peer_id)}


func token_of(civilization_id: int) -> String:
	var peer_id := peer_of(civilization_id)
	return _peers[peer_id].token if peer_id != 0 else ""


## Caiu e ainda dentro da janela de volta?
func is_waiting(civilization_id: int) -> bool:
	var peer_id := peer_of(civilization_id)
	return peer_id != 0 and not _peers[peer_id].connected and not _peers[peer_id].expired


func peer_of(civilization_id: int) -> int:
	for peer_id: int in _peers:
		if _peers[peer_id].civ == civilization_id:
			return peer_id
	return 0


## Aplica um comando do jogador. Devolve true só se foi aceito; qualquer recusa fica no registro e não muda nada.
func handle_command(peer_id: int, msg: Variant) -> bool:
	var session: Dictionary = _peers.get(peer_id, {})
	if session.is_empty():
		net_log.add(0, "peer_desconhecido", "aviso", "comando do peer %d descartado" % peer_id)
		return false
	var civ: int = session.civ
	var cmd := NetProtocol.parse(msg)
	if not cmd.ok:
		net_log.add(civ, cmd.reason, "aviso", "comando descartado")
		return false
	if _eliminated.has(civ):
		net_log.add(civ, "jogador_eliminado", "aviso", "comando descartado")
		return false
	if cmd.seq <= session.seq:   # repetido ou atrasado: já valemos algo mais novo
		net_log.add(civ, "seq_antigo", "info", "comando descartado")
		return false
	session.seq = cmd.seq
	session.steering.steer = cmd.steer
	return true


## Foto do estado REAL da partida: é o que os clientes desenham e com o que se reconciliam.
func snapshot() -> Dictionary:
	var players: Array = []
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		var id: int = runner.get_node("Civilization").id
		var health := runner.get_node_or_null("Health") as Health
		players.append({
			"id": id,
			"pos": runner.global_position,
			"fwd": runner.forward,
			"hp": health.points if health != null else 0,
			"alive": not _eliminated.has(id),
			"dom": Services.stats.dominance(id) if Services.stats != null else 0.0,
		})
	return {
		"tick": tick,
		"left": _seconds_left(),
		"state": Services.flow.state if Services.flow != null else -1,
		"players": players,
		"ranking": Services.stats.ranking() if Services.stats != null else [],
	}


## O snapshot de um jogador traz também o último comando dele que o servidor aplicou (base da predição).
func snapshot_for(peer_id: int) -> Dictionary:
	var shot := snapshot()
	shot["ack"] = _peers.get(peer_id, {}).get("seq", -1)
	return shot


## Tudo que o cliente precisa para voltar à partida: estado oficial (posições, vidas, relógio, evento ativo = `state`,
## ranking), o mapa de territórios inteiro e os bônus ativos de cada corredor.
func full_state(peer_id: int) -> Dictionary:
	var state := snapshot_for(peer_id)
	var session: Dictionary = _peers.get(peer_id, {})
	state["civ"] = session.get("civ", 0)
	state["token"] = session.get("token", "")
	state["window"] = reconnect_window
	state["territory"] = Services.territory.owners_snapshot() if Services.territory != null else PackedByteArray()
	var bonuses := {}
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		var health := runner.get_node_or_null("Health") as Health
		bonuses[runner.get_node("Civilization").id] = {
			"speed": runner.speed_multiplier, "freeze": runner.freeze_multiplier, "slow": runner.slow_multiplier,
			"shield": health.shield_left if health != null else 0.0,
		}
	state["bonuses"] = bonuses
	return state


func _seconds_left() -> int:
	var timer := get_tree().get_first_node_in_group("match_timer") as MatchTimer
	return timer.seconds_left() if timer != null else -1


func _refuse(civilization_id: int, reason: String, peer_id: int) -> Dictionary:
	net_log.add(civilization_id, reason, "aviso", "reconexão recusada (peer %d)" % peer_id)
	return {"ok": false, "reason": reason}


func _expire(session: Dictionary) -> void:
	session.expired = true
	net_log.add(session.civ, "reconexao_expirada", "grave", "tempo de volta esgotado: jogador eliminado")
	var health := _runner_of(session.civ).get_node_or_null("Health") as Health
	if health != null:
		health.eliminate()


func _new_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _runner_of(civilization_id: int) -> PlanetRunner:
	for node in get_tree().get_nodes_in_group("runners"):
		if node.get_node("Civilization").id == civilization_id:
			return node as PlanetRunner
	return null
