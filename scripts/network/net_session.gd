class_name NetSession
extends Node
## Transporte da partida (Adendo 06): ENet + API de RPC de alto nível do Godot. O MESMO nó vive nos dois lados
## (o caminho e os RPCs precisam coincidir): host() o torna o servidor autoritário (MatchServer dentro dele),
## connect_to() o torna cliente. O cliente manda direção (submit); o servidor devolve boas-vindas e snapshots.

signal connected                                   # cliente: o servidor aceitou a conexão
signal disconnected                                # cliente: perdeu o servidor ou foi recusado
signal welcome_received(civilization_id: int)      # cliente: qual civilização é a minha
signal snapshot_received(snapshot: Dictionary)     # cliente: estado real da partida

const SNAPSHOT_HZ := 20.0

var match_server: MatchServer = null   # só no servidor
var my_civ := 0
var last_snapshot: Dictionary = {}

var _seq := 0
var _snapshot_clock := 0.0


func host(port: int, max_clients := 5) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	match_server = MatchServer.new()
	add_child(match_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK


func connect_to(address: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func(): connected.emit())
	multiplayer.server_disconnected.connect(func(): disconnected.emit())
	multiplayer.connection_failed.connect(func(): disconnected.emit())
	return OK


func close() -> void:
	multiplayer.multiplayer_peer = null


## Cliente: pede ao servidor para virar. Devolve o número do comando (a predição guarda o que ainda não foi confirmado).
func send_steer(value: float) -> int:
	_seq += 1
	submit.rpc_id(1, {"type": "steer", "seq": _seq, "steer": value})
	return _seq


func _process(delta: float) -> void:
	if match_server == null:
		return
	_snapshot_clock += delta
	if _snapshot_clock < 1.0 / SNAPSHOT_HZ:
		return
	_snapshot_clock = 0.0
	for peer_id in multiplayer.get_peers():
		if match_server.has_peer(peer_id):
			deliver.rpc_id(peer_id, match_server.snapshot_for(peer_id))


func _on_peer_connected(peer_id: int) -> void:
	var civ := match_server.free_civilization()
	if civ == 0 or not match_server.join(peer_id, civ):
		match_server.net_log.add(0, "partida_cheia", "aviso", "peer %d recusado" % peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	welcome.rpc_id(peer_id, civ)


func _on_peer_disconnected(peer_id: int) -> void:
	match_server.peer_left(peer_id)


# Variant, não Dictionary: o que chega da rede nunca é confiável, quem valida é o NetProtocol.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit(msg: Variant) -> void:
	if match_server != null:
		match_server.handle_command(multiplayer.get_remote_sender_id(), msg)


@rpc("authority", "call_remote", "reliable")
func welcome(civilization_id: int) -> void:
	my_civ = civilization_id
	welcome_received.emit(civilization_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func deliver(snapshot: Dictionary) -> void:
	last_snapshot = snapshot
	snapshot_received.emit(snapshot)
