class_name MatchServer
extends Node
## O servidor da partida (DD-041..043): a ÚNICA autoridade. O cliente só envia comandos de direção
## (NetProtocol); o servidor valida, aplica ao corredor da civilização daquele jogador e devolve
## snapshots do estado real. Cliente nenhum cria território, tira vidas ou decide vencedor.
## Independe do transporte: handle_command() recebe um Dictionary, venha de ENet (Passo 25) ou de teste.

var net_log := NetLog.new()
var tick := 0

var _peers: Dictionary = {}       # peer_id -> {civ: int, seq: int, steering: RemoteSteering}
var _eliminated: Dictionary = {}  # civ_id -> true (quem o servidor viu cair; comandos dele são ignorados)
var _time_left := -1


func _ready() -> void:
	EventBus.civilization_eliminated.connect(func(id: int): _eliminated[id] = true)
	EventBus.match_clock_changed.connect(func(seconds: int): _time_left = seconds)


func _physics_process(_delta: float) -> void:
	tick += 1


## Entrega o corredor da civilização ao jogador remoto. Um jogador por civilização e vice-versa.
func join(peer_id: int, civilization_id: int) -> bool:
	var runner := _runner_of(civilization_id)
	if runner == null or _peers.has(peer_id) or peer_of(civilization_id) != 0:
		net_log.add(civilization_id, "join_recusado", "aviso", "peer %d ignorado" % peer_id)
		return false
	var driver := RemoteSteering.new()
	runner.use_steering(driver)
	_peers[peer_id] = {"civ": civilization_id, "seq": -1, "steering": driver}
	return true


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
		"left": _time_left,
		"state": Services.flow.state if Services.flow != null else -1,
		"players": players,
		"ranking": Services.stats.ranking() if Services.stats != null else [],
	}


## O snapshot de um jogador traz também o último comando dele que o servidor aplicou (base da predição).
func snapshot_for(peer_id: int) -> Dictionary:
	var shot := snapshot()
	shot["ack"] = _peers.get(peer_id, {}).get("seq", -1)
	return shot


func _runner_of(civilization_id: int) -> PlanetRunner:
	for node in get_tree().get_nodes_in_group("runners"):
		if node.get_node("Civilization").id == civilization_id:
			return node as PlanetRunner
	return null
