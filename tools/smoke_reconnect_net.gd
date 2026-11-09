extends SceneTree
## Teste de fumaça do Passo 27, lado do CLIENTE e da rede de verdade (ENet em 127.0.0.1): o servidor derruba a conexão
## do jogador, o cliente percebe, reconecta sozinho com o token e volta com o estado completo (controle devolvido,
## predição recomeçada, token renovado); outro cliente com o token da sessão ativa ou com um token velho é recusado;
## sem servidor, o cliente desiste ao fim da janela.
## Uso: godot_console --headless --path . -s res://tools/smoke_reconnect_net.gd

const PORT := 24682

var _match: Node
var _time := 0.0
var _dt := 0.016
var _server: Node
var _a: Node


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	root.add_child(_match)
	_run()


func _process(delta: float) -> bool:
	_time += delta
	_dt = delta
	if _time > 90.0:
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


func _runner(civ: int) -> Node:
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == civ:
			return r
	return null


func _run() -> void:
	await root.get_node("EventBus").match_started
	for i in 10:
		await process_frame

	_server = _side("ServerSide")
	if not _check(_server.host(PORT) == OK, "servidor ENet deve abrir a porta"): return
	var log_ref: RefCounted = _server.match_server.net_log
	_a = _side("ClientA")
	if not _check(_a.connect_to("127.0.0.1", PORT) == OK, "cliente A deve iniciar a conexão"): return
	if not _check(await _until(func(): return _a.my_civ != 0 and _a.predictor != null), "A deve entrar e ter predição"): return
	var token0: String = _a.session_token
	if not _check(token0.length() >= 32 and _a.reconnect_window == _server.match_server.reconnect_window, "A recebe token e a janela do servidor"): return
	var runner := _runner(1)
	for i in 30:
		_a.send_steer(1.0, _dt)
		await process_frame

	# A rede cai: o servidor derruba a conexão. O cliente percebe e volta sozinho.
	var lost := [false]
	var back: Array = [null]
	_a.disconnected.connect(func(): lost[0] = true)
	_a.reconnected.connect(func(state: Dictionary): back[0] = state)
	var old_peer: int = _server.match_server.peer_of(1)
	_server.multiplayer.multiplayer_peer.disconnect_peer(old_peer)
	if not _check(await _until(func(): return lost[0]), "A deve perceber a queda"): return
	if not _check(is_equal_approx(_a.send_steer(1.0, _dt), 30.0), "fora do ar o cliente não manda nem prevê comando"): return
	if not _check(await _until(func(): return back[0] != null, 10.0), "A deve reconectar sozinho"): return
	var state: Dictionary = back[0]
	var new_peer: int = _server.match_server.peer_of(1)
	if not _check(new_peer != 0 and new_peer != old_peer and _a.my_civ == 1, "A volta como civilização 1 em outro peer"): return
	if not _check(log_ref.count("peer_desconectado") == 1 and log_ref.count("reconexao_aceita") == 1, "queda e volta ficam no registro"): return
	if not _check(_a.session_token != token0 and _a.session_token == state.token, "o token é renovado a cada volta"): return
	if not _check(state.territory.size() > 0 and state.players.size() == 2 and state.left > 0 and state.bonuses.has(1), "estado completo recebido"): return
	if not _check(_a.predictor != null and _a.predictor.is_ready() and _a.predictor.pending.is_empty(), "predição recomeçou do estado oficial"): return

	# Controle devolvido: o comando do cliente volta a virar o corredor (numeração recomeçou)
	var fwd_before: Vector3 = runner.forward
	for i in 20:
		_a.send_steer(-1.0, _dt)
		await process_frame
	if not _check(runner.forward.angle_to(fwd_before) > 0.2, "depois da volta o corredor obedece ao jogador de novo"): return
	if not _check(await _until(func(): return _a.last_snapshot.get("ack", -1) >= 20), "snapshots com ack voltam a chegar"): return

	# Nenhum login novo toma a sessão: nem com o token ativo, nem com um token velho
	var x1 := _side("ClientX1")
	x1.session_token = _a.session_token
	var x1_reason := [""]
	x1.reconnect_failed.connect(func(reason: String): x1_reason[0] = reason)
	x1.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return x1_reason[0] != ""), "token da sessão ativa não entrega a sessão"): return
	if not _check(x1_reason[0] == "sessao_ativa" and _server.match_server.peer_of(1) == new_peer, "A continua dono da sessão (%s)" % x1_reason[0]): return
	var x2 := _side("ClientX2")
	x2.session_token = token0
	var x2_reason := [""]
	x2.reconnect_failed.connect(func(reason: String): x2_reason[0] = reason)
	x2.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return x2_reason[0] != ""), "token velho não vale"): return
	if not _check(x2_reason[0] == "token_invalido", "token velho recusado (%s)" % x2_reason[0]): return
	if not _check(log_ref.count("sessao_ativa") == 1 and log_ref.count("token_invalido") == 1, "as duas tentativas ficam no registro"): return

	# Sem servidor: o cliente tenta até o fim da janela e desiste
	_a.reconnect_window = 1.5
	var failed := [""]
	_a.reconnect_failed.connect(func(reason: String): failed[0] = reason)
	_server.close()
	if not _check(await _until(func(): return failed[0] != "", 15.0), "sem servidor o cliente deve desistir"): return
	if not _check(failed[0] == "janela_esgotada", "motivo da desistência (%s)" % failed[0]): return
	print("OK")
	quit(0)
