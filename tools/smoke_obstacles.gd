extends SceneTree
## Teste de fumaça do Passo 10 (SYS-007 Obstáculos): (1) nenhum par de obstáculos sólidos fecha a rota (corredor
## livre >= 2,0); (2) o corredor posto dentro de um obstáculo é empurrado para fora; (3) meteoro arrasa o obstáculo
## por um tempo (passa direto) e depois ele volta; (4) troca de dono: o obstáculo antigo ENCOLHE (animação) e o
## território velho fica sem nada. Uso: godot_console --headless --path . -s res://tools/smoke_obstacles.gd

var _match: Node
var _bus: Node
var _services: Node
var _slots: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_services = root.get_node("Services")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _wait(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _solid_revealed() -> Array:
	var out := []
	for i in _slots._dirs.size():
		if _slots._key[i] >= 0 and _slots.SOLID_RADIUS[_slots._category[i]] > 0.0:
			out.append(i)
	return out


func _run() -> void:
	await _bus.match_started
	for i in 5:
		await process_frame
	_slots = _match.get_node("Main/Slots")
	var planet: Node = _services.planet
	var map: Node = _match.get_node("Main/Territory")
	var runner: Node3D = _match.get_node("Main/Runner")
	var health: Node = runner.get_node("Health")
	runner.set_process(false)   # parado: só o ObstacleSystem mexe nele
	var base_dir: Vector3 = (_services.home_bases[1]["position"] - planet.center).normalized()
	map.claim_cap(1, base_dir, 1.2)
	if not _check(await _wait(func(): return _solid_revealed().size() >= 5, 400), "poucos obstáculos revelados (%d)" % _solid_revealed().size()): return
	await _wait(func(): return false, 90)   # deixa o crescimento (0,9 s) acabar

	# 1. Nunca bloqueia a rota: corredor >= 2,0 entre quaisquer dois sólidos
	var solids := _solid_revealed()
	var worst := 99.0
	for a in solids.size():
		for b in range(a + 1, solids.size()):
			var i: int = solids[a]
			var j: int = solids[b]
			var gap: float = acos(clampf(_slots._dirs[i].dot(_slots._dirs[j]), -1.0, 1.0)) * planet.radius \
					- _slots.SOLID_RADIUS[_slots._category[i]] - _slots.SOLID_RADIUS[_slots._category[j]]
			worst = minf(worst, gap)
	print("obstáculos sólidos=%d, menor corredor=%.2f" % [solids.size(), worst])
	if not _check(worst >= 2.0, "dois obstáculos fecham a rota (corredor %.2f)" % worst): return

	# 1b. push_out otimizado (só sólidos + corda²) dá o MESMO deslocamento da conta direta sobre todos os slots
	var worst_diff := 0.0
	for n in 60:
		var probe_dir: Vector3 = _slots._dirs[solids[n % solids.size()]].rotated(Vector3.UP, 0.004 * n).normalized()
		var probe: Vector3 = planet.center + probe_dir * (planet.get_surface_radius(probe_dir) + 0.1 * (n % 3))
		var expected := Vector3.ZERO
		var height: float = (probe - planet.center).length()
		for k in _slots._dirs.size():
			var r: float = _slots.SOLID_RADIUS[_slots._category[k]]
			if _slots._key[k] < 0 or r <= 0.0:
				continue
			var diff: Vector3 = probe - (planet.center + _slots._dirs[k] * height)
			var d := diff.length()
			if d < r + 0.6:
				expected += (diff / d if d > 0.01 else Vector3.RIGHT) * (r + 0.6 - d)
		worst_diff = maxf(worst_diff, (_slots.push_out(probe, 0.6) - expected).length())
	if not _check(worst_diff < 0.001, "push_out difere da conta direta em %.4f" % worst_diff): return

	# 2. Colisão: corredor perto do centro do obstáculo é empurrado para a borda
	var target: int = solids[0]
	var dir: Vector3 = _slots._dirs[target]
	var reach: float = _slots.SOLID_RADIUS[_slots._category[target]]
	var axis: Vector3 = dir.cross(Vector3.UP)
	axis = (axis if axis.length() > 0.1 else dir.cross(Vector3.RIGHT)).normalized()
	var near_dir: Vector3 = dir.rotated(axis, 0.3 / planet.radius)
	runner.teleport_to(planet.center + near_dir * planet.get_surface_radius(near_dir))
	for i in 3:
		await process_frame
	var height: float = (runner.global_position - planet.center).length()
	var d: float = (runner.global_position - (planet.center + dir * height)).length()
	var obstacle_point: Vector3 = planet.center + dir * height
	var expected: float = reach + _match.get_node("Obstacles").body_radius
	print("colisão: distância ao centro=%.2f (borda=%.2f)" % [d, expected])
	if not _check(d >= expected - 0.05, "corredor continuou dentro do obstáculo (%.2f < %.2f)" % [d, expected]): return

	# 3. Meteoro arrasa a área por um tempo; depois o obstáculo volta
	_match.get_node("Obstacles").event_clear_seconds = 1.0
	_bus.radial_damage.emit(obstacle_point, 6.0, 0, false, 12.0, 0, 20.0, 0)
	if not _check(_slots._suppressed.has(target), "o meteoro deveria marcar o obstáculo como destruído"): return
	if not _check(await _wait(func(): return _slots._key[target] == -1, 400), "o obstáculo destruído deveria sumir"): return
	if not _check(_slots.push_out(obstacle_point, 0.6) == Vector3.ZERO, "obstáculo destruído não deve colidir"): return
	if not _check(await _wait(func(): return _slots._key[target] >= 0, 800), "o obstáculo deveria voltar depois do evento"): return
	if not _check(health.points == 16, "dano 0 não pode ferir (%d)" % health.points): return

	# 4. Troca de dono: o obstáculo antigo encolhe e some; o território velho fica sem nada
	map.claim_cap(2, base_dir, 1.2)
	var saw_leaving := false
	for i in 400:
		await process_frame
		if _slots._leaving.size() > 0:
			saw_leaving = true
		if saw_leaving and _slots._leaving.is_empty() and _slots.revealed_count(1, false) == 0:
			break
	if not _check(saw_leaving, "a troca de dono deveria animar a saída do obstáculo antigo"): return
	if not _check(_slots._leaving.is_empty(), "a animação de saída deveria terminar"): return
	if not _check(_slots.revealed_count(1, false) == 0, "ainda há %d slots do dono antigo" % _slots.revealed_count(1, false)): return
	print("OK")
	quit(0)
