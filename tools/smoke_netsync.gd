extends SceneTree
## Teste de fumaça do Passo 37 (Cap.04 parte 03/05, DD-133): (1) RemoteInterpolator desenha o corredor remoto no arco
## entre dois snapshots, para quando nada mais novo chega, teletransporta em salto grande e ignora pacote fora de ordem;
## (2) em ENet de verdade, o cliente enxerga o OUTRO corredor suavizado (e não o próprio); (3) o detector de
## dessincronia: hash batendo = nada acontece; hash divergente = o servidor reenvia o estado oficial, uma vez por
## intervalo; relato inválido é descartado e registrado.
## Uso: godot_console --headless --path . -s res://tools/smoke_netsync.gd

const PORT := 24684

class StubPlanet:
	var center := Vector3(10.0, 0.0, 0.0)

var _match: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	root.add_child(_match)
	_run()


func _process(delta: float) -> bool:
	_time += delta
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


func _wait(seconds: float) -> void:
	var limit := _time + seconds
	while _time < limit:
		await process_frame


func _interpolation() -> bool:
	var planet := StubPlanet.new()
	var interp: RefCounted = load("res://scripts/network/remote_interpolator.gd").new(planet)
	var c: Vector3 = planet.center
	var radius := 101.0
	var angle := 0.01   # ~1 unidade entre snapshots: o passo real de um corredor
	var pos_a := c + Vector3(radius, 0.0, 0.0)
	var pos_b := c + Vector3(cos(angle), 0.0, sin(angle)) * radius
	if not _check(interp.sample(1, 0.0).is_empty(), "sem notícias, não há pose"): return false
	interp.push(1, 0.0, pos_a, Vector3(0.0, 0.0, 1.0))
	interp.push(1, 0.05, pos_b, Vector3(-sin(angle), 0.0, cos(angle)))
	var mid: Dictionary = interp.sample(1, 0.125)   # 0,125 - atraso de 0,1 = 0,025: metade do caminho
	var mid_angle: float = (mid.pos - c).angle_to(pos_a - c)
	if not _check(absf(mid_angle - angle * 0.5) < 0.0005, "no meio do caminho o ângulo é metade (%f)" % mid_angle): return false
	if not _check(absf((mid.pos - c).length() - radius) < 0.0003, "o corredor percorre o ARCO do planeta, não a corda (%f)" % (mid.pos - c).length()): return false
	if not _check((mid.fwd as Vector3).is_equal_approx(Vector3(-sin(angle * 0.5), 0.0, cos(angle * 0.5))), "a direção também é interpolada"): return false
	if not _check(interp.sample(1, 0.05).pos == pos_a, "antes do primeiro snapshot parado no primeiro"): return false
	if not _check(interp.sample(1, 5.0).pos == pos_b, "sem snapshot mais novo, para onde está (não inventa o futuro)"): return false
	interp.push(1, 0.02, c + Vector3(0.0, radius, 0.0), Vector3(0.0, 0.0, 1.0))   # fora de ordem
	if not _check(interp.sample(1, 0.125).pos.is_equal_approx(mid.pos), "pacote fora de ordem é ignorado"): return false
	interp.push(1, 0.1, c + Vector3(-radius, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))   # salto de ~200 unidades
	if not _check(interp.sample(1, 0.2).pos == c + Vector3(-radius, 0.0, 0.0), "salto grande teletransporta, não desliza"): return false
	for i in 20:
		interp.push(2, 1.0 + i * 0.05, pos_a, Vector3(0.0, 0.0, 1.0))
	if not _check(interp._buffers[2].size() <= interp.MAX_SAMPLES, "o buffer tem limite"): return false
	return true


func _run() -> void:
	if not _interpolation():
		return
	await root.get_node("EventBus").match_started
	for i in 10:
		await process_frame
	var server := _side("ServerSide")
	if not _check(server.host(PORT) == OK, "servidor ENet deve abrir a porta"): return
	var matchsrv: Node = server.match_server
	var a := _side("ClientA")
	a.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return a.my_civ != 0 and a.predictor != null), "A deve entrar e ter predição"): return

	# Corredor remoto suavizado (o próprio não: é previsto)
	var bot: Node
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id != a.my_civ:
			bot = r
	var bot_id: int = bot.get_node("Civilization").id
	if not _check(await _until(func(): return not a.remote_pose(bot_id).is_empty()), "A deve ter a pose do outro corredor"): return
	await _wait(0.5)
	var pose: Dictionary = a.remote_pose(bot_id)
	if not _check(pose.pos.distance_to(bot.global_position) < 4.0, "a pose suavizada acompanha o corredor real (%f)" % pose.pos.distance_to(bot.global_position)): return
	if not _check(a.remote_pose(a.my_civ).is_empty(), "o próprio corredor não passa pelo suavizador"): return

	# Detector: réplica perfeita (o hash que o servidor tinha naquele tick) nunca dispara nada
	var states: Array = []
	a.resynced_with_server.connect(func(state: Dictionary): states.append(state))
	a.local_digest = func(): return matchsrv.digest_at(a.last_snapshot.tick)
	if not _check(await _until(func(): return matchsrv.digests_checked >= 3, 4.0), "o servidor deve conferir os relatos do cliente"): return
	await _wait(0.5)
	if not _check(states.is_empty() and matchsrv.net_log.count("divergencia_detectada") == 0, "hash batendo: nenhum reenvio"): return

	# Réplica divergente: o servidor percebe sozinho e reenvia o estado oficial (no máximo 1 vez por intervalo)
	a.local_digest = func(): return (matchsrv.digest_at(a.last_snapshot.tick) as int) + 1
	if not _check(await _until(func(): return states.size() == 1, 3.0), "divergência: o servidor reenvia o estado oficial"): return
	if not _check(states[0].civ == a.my_civ and states[0].territory.size() > 0, "estado oficial completo"): return
	await _wait(0.3)
	if not _check(states.size() == 1, "dentro do intervalo, não reenvia de novo"): return
	if not _check(await _until(func(): return states.size() >= 2, 4.0), "passado o intervalo, atende de novo"): return
	if not _check(matchsrv.net_log.count("resync_excessivo") >= 1, "o excesso fica registrado"): return

	# Réplica consertada: acabou
	a.local_digest = func(): return matchsrv.digest_at(a.last_snapshot.tick)
	await _wait(0.3)
	var settled: int = states.size()
	await _wait(1.5)
	if not _check(states.size() == settled, "réplica consertada: o reenvio para"): return

	# Relato inválido ou de tick esquecido
	var peer_id: int = matchsrv._peers.keys()[0]
	var checked: int = matchsrv.digests_checked
	if not _check(not matchsrv.verify_digest(peer_id, "x", 1.5).diverged and matchsrv.net_log.count("relato_invalido") == 1, "relato inválido é descartado e registrado"): return
	var old: Dictionary = matchsrv.verify_digest(peer_id, -5, 1)
	if not _check(old.ok and not old.diverged and matchsrv.digests_checked == checked, "tick esquecido não se confere"): return
	if not _check(not matchsrv.verify_digest(9999, 1, 1).ok, "relato de quem não é jogador é descartado"): return
	print("OK")
	quit(0)
