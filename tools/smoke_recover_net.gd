extends SceneTree
## Teste de fumaça do Passo 28, lado do CLIENTE e da rede de verdade (ENet em 127.0.0.1): o cliente dessincronizado
## pede o estado oficial, o servidor reenvia (predição recomeça do estado oficial, numeração dos comandos continua)
## e uma rajada de pedidos é atendida UMA vez só.
## Uso: godot_console --headless --path . -s res://tools/smoke_recover_net.gd

const PORT := 24683

var _match: Node
var _time := 0.0
var _dt := 0.016


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	root.add_child(_match)
	_run()


func _process(delta: float) -> bool:
	_time += delta
	_dt = delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _side(side_name: String) -> Node:
	var side := Node.new()
	side.name = side_name
	root.add_child(side)
	set_multiplayer(SceneMultiplayer.new(), side.get_path())
	var net: Node = load("res://scripts/network/net_session.gd").new()
	net.name = "Net"
	side.add_child(net)
	return net


func _until(condition: Callable, seconds := 5.0) -> bool:
	var limit := _time + seconds
	while not condition.call():
		if _time > limit:
			return false
		await process_frame
	return true


func _run() -> void:
	await root.get_node("EventBus").match_started
	for i in 10:
		await process_frame
	var server := _side("ServerSide")
	if not _check(server.host(PORT) == OK, "servidor ENet deve abrir a porta"): return
	server.match_server.resync_interval = 1.0
	var log_ref: RefCounted = server.match_server.net_log
	var a := _side("ClientA")
	a.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return a.my_civ != 0 and a.predictor != null), "A deve entrar e ter predição"): return
	for i in 20:
		a.send_steer(1.0, _dt)
		await process_frame
	var runner: Node
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == 1:
			runner = r

	# Cliente dessincronizado (a predição foi parar longe): pede o estado oficial
	var old_predictor: RefCounted = a.predictor
	var states: Array = []
	a.resynced_with_server.connect(func(state: Dictionary): states.append(state))
	old_predictor.position += Vector3(3.0, 0.0, 0.0)
	var seq_before: int = a.send_steer(1.0, _dt)
	for i in 7:   # rajada: 1 pedido legítimo + 6 em cima dele
		a.request_resync()
	if not _check(await _until(func(): return states.size() == 1), "o servidor deve reenviar o estado oficial"): return
	var state: Dictionary = states[0]
	if not _check(state.civ == 1 and state.territory.size() > 0 and state.players.size() == 2 and state.token == a.session_token, "estado oficial completo"): return
	if not _check(a.predictor != old_predictor and a.predictor.is_ready() and a.predictor.pending.is_empty(), "a predição recomeçou do estado oficial"): return
	if not _check(a.predictor.position.distance_to(runner.global_position) < 2.0, "e voltou a acompanhar o corredor real"): return
	if not _check(a.send_steer(1.0, _dt) == seq_before + 1, "a numeração dos comandos continua (a sessão é a mesma)"): return
	var applied := func() -> bool:   # como no jogo: um comando por quadro enquanto espera
		a.send_steer(1.0, _dt)
		return a.last_snapshot.get("ack", -1) > seq_before
	if not _check(await _until(applied), "o servidor continua aplicando os comandos do A depois do resync"): return

	await create_timer(0.3).timeout
	if not _check(states.size() == 1, "a rajada gerou um estado só (%d)" % states.size()): return
	if not _check(log_ref.count("dessincronizacao") == 1 and log_ref.count("resync_excessivo") == 1, "1 atendido, excesso registrado uma vez"): return
	await create_timer(1.2).timeout
	a.request_resync()
	if not _check(await _until(func(): return states.size() == 2), "passado o intervalo, volta a ser atendido"): return
	print("OK")
	quit(0)
