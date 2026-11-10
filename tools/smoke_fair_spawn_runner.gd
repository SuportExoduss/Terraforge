extends SceneTree
## Teste de fumaça do Passo 63 (Cap.03 P06 RESPAWN): o pouso da nave também fica a >= 0,3 rad de corredor adversário em campo
## (o próprio corredor e quem não está em campo não contam). Uso: godot_console --headless --path . -s res://tools/smoke_fair_spawn_runner.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 2
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var planet: Node = root.get_node("Services").planet
	var home: Node = _match.get_node("Main/HomeBase")   # civilização 1 (jogador)
	var player: Node3D = _match.get_node("Main/Runner")
	var rival: Node3D = _match.get_node("Main/Runner2")
	var third: Node3D = _match.get_node("Main/Runner3")
	for r in [player, rival, third]:
		r.set_process(false)

	# Ponto de teste: 90° de todas as bases na linha do equador, longe do rival e do terceiro (estão em outras bases)
	var spot_dir: Vector3 = (home.global_position - planet.center).normalized().rotated(Vector3.UP, 0.9)
	var spot: Vector3 = planet.center + spot_dir * planet.get_surface_radius(spot_dir)
	if not _check(rival.is_active_in_field(), "o rival deveria estar em campo"): return
	if not _check(home.is_fair_spot(spot), "sem ninguém por perto o ponto deveria ser justo"): return

	# 1. Rival em cima do ponto: recusado; a 0,2 rad: recusado; a 0,4 rad: aceito
	var axis: Vector3 = spot_dir.cross(Vector3.UP).normalized()
	rival.teleport_to(spot)
	if not _check(not home.is_fair_spot(spot), "rival em cima do ponto: deveria recusar"): return
	var near_dir: Vector3 = spot_dir.rotated(axis, 0.2)
	rival.teleport_to(planet.center + near_dir * planet.get_surface_radius(near_dir))
	if not _check(not home.is_fair_spot(spot), "rival a 0,2 rad: deveria recusar"): return
	var far_dir: Vector3 = spot_dir.rotated(axis, 0.4)
	rival.teleport_to(planet.center + far_dir * planet.get_surface_radius(far_dir))
	if not _check(home.is_fair_spot(spot), "rival a 0,4 rad: deveria aceitar"): return

	# 2. O corredor da própria civilização no ponto não conta (ele mesmo está na nave)
	player.teleport_to(spot)
	if not _check(home.is_fair_spot(spot), "o próprio corredor não deveria recusar o pouso"): return

	# 3. Sorteio: com o rival no ponto, 100 pousos ficam a >= 0,3 rad dele
	rival.teleport_to(spot)
	for n in 100:
		var pick: Vector3 = home._pick_landing_position()
		var arc: float = ((pick - planet.center).normalized()).angle_to((rival.global_position - planet.center).normalized())
		if not _check(arc >= home.RUNNER_SAFE_ARC - 0.0001, "pouso sorteado a %.2f rad do rival" % arc): return

	print("OK: pouso evita corredor adversário em campo (>= 0,3 rad); o próprio corredor não conta")
	quit(0)
