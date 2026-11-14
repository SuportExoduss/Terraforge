extends SceneTree
## Teste de fumaça do Passo 100 (SYS-007, "Tsunami alaga caminhos"): a onda que passa por cima de um obstáculo sólido o faz
## SUMIR (não colide mais), um obstáculo longe da faixa continua lá, e DEPOIS do evento o alagado volta ao normal.
## Tempos encurtados por exportação. Uso: godot_console --headless --path . -s res://tools/smoke_flood_obstacles.gd

const ACTIVE := 3   # GlobalEvent.State.ACTIVE (sem citar a classe em scripts -s)

var _match: Node
var _bus: Node
var _tsunami: Node3D
var _slots: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	_tsunami = _match.get_node("Tsunami")
	_tsunami.min_seconds_between = 1.0
	_tsunami.max_seconds_between = 1.0
	_tsunami.quiet_after_start_seconds = 0.5
	_tsunami.warning_seconds = 1.0
	_tsunami.scar_seconds = 1.0
	_tsunami.wave_speed = 60.0
	_tsunami.travel_degrees = 120.0
	_tsunami.flood_clear_seconds = 1.5
	root.add_child(_match)
	_bus = root.get_node("EventBus")
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
	var services: Node = root.get_node("Services")
	var planet: Node = services.planet
	var runner: Node3D = _match.get_node("Main/Runner")
	runner.set_process(false)
	var base_dir: Vector3 = (services.home_bases[1]["position"] - planet.center).normalized()
	_match.get_node("Main/Territory").claim_cap(1, base_dir, 1.2)
	if not _check(await _wait(func(): return _solid_revealed().size() >= 5, 400), "poucos obstáculos revelados"): return
	await _wait(func(): return false, 90)   # deixa o crescimento (0,9 s) acabar

	# O alvo: um sólido qualquer; a onda sai 40° antes dele e passa por cima. O controle: o sólido mais longe da trajetória.
	var solids := _solid_revealed()
	var target: int = solids[0]
	var dir: Vector3 = _slots._dirs[target]
	var helper := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
	var start := dir.rotated(dir.cross(helper).normalized(), deg_to_rad(40.0)).normalized()
	var travel := (dir - start * start.dot(dir)).normalized()   # do ponto de partida para o alvo
	var normal := start.cross(travel)
	var control := target
	var control_side := 0.0
	for i in solids:
		var side: float = absf(asin(clampf(_slots._dirs[i].dot(normal), -1.0, 1.0))) * planet.radius
		if side > control_side:
			control_side = side
			control = i
	print("obstáculos sólidos=%d  controle a %.0f u da trajetória da onda" % [solids.size(), control_side])
	if not _check(control_side > 80.0, "sem obstáculo longe da trajetória para servir de controle"): return
	var point: Vector3 = planet.center + dir * planet.radius
	var control_point: Vector3 = planet.center + _slots._dirs[control] * planet.radius

	await _bus.global_event_warning
	_tsunami.plan(start, travel)
	if not _check(not _slots._suppressed.has(target), "antes da onda o obstáculo está de pé"): return
	if not _check(await _wait(func(): return _tsunami.state == ACTIVE, 400), "a onda não começou"): return

	# A onda passa pelo alvo: ele some e não colide
	if not _check(await _wait(func(): return _slots._suppressed.has(target), 400), "a onda deveria alagar o obstáculo"): return
	if not _check(await _wait(func(): return _slots._key[target] == -1, 400), "o obstáculo alagado deveria sumir"): return
	if not _check(_slots.push_out(point, 0.6) == Vector3.ZERO, "obstáculo alagado não deve colidir"): return
	if not _check(not _slots._suppressed.has(control) and _slots._key[control] >= 0, "o obstáculo longe da onda não pode sumir"): return
	print("alagado: sumiu e não colide; o de longe continua de pé")

	# Depois do evento tudo volta ao normal
	if not _check(await _wait(func(): return _slots._key[target] >= 0, 900), "o obstáculo alagado deveria voltar depois da onda"): return
	if not _check(_slots.push_out(point, 0.6) != Vector3.ZERO, "o obstáculo que voltou deve colidir de novo"): return
	if not _check(_slots.push_out(control_point, 0.6) != Vector3.ZERO, "o controle continua colidindo"): return
	print("OK")
	quit(0)
