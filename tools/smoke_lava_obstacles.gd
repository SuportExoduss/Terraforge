extends SceneTree
## Teste de fumaça do Passo 101 (SYS-007, "Vulcão cria áreas de lava temporárias"): quando o vulcão entra em erupção, os obstáculos
## sólidos em cima do solo escuro (raio = metade do soil_diameter) SOMEM e não colidem; os de fora ficam; e quando a cicatriz acaba
## eles voltam. Tempos encurtados por exportação.
## Uso: godot_console --headless --path . -s res://tools/smoke_lava_obstacles.gd

const ACTIVE := 3   # GlobalEvent.State.ACTIVE (sem citar a classe em scripts -s)

var _match: Node
var _bus: Node
var _volcano: Node3D
var _slots: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	_volcano = _match.get_node("Volcano")
	_volcano.min_seconds_between = 1.0
	_volcano.max_seconds_between = 1.0
	_volcano.quiet_after_start_seconds = 0.5
	_volcano.warning_seconds = 1.0
	_volcano.eruption_seconds = 3.0
	_volcano.scar_seconds = 2.0
	_volcano.launch_interval = 0.5
	_volcano.flight_seconds = 0.6
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
	_match.get_node("Main/Runner").set_process(false)
	var base_dir: Vector3 = (services.home_bases[1]["position"] - planet.center).normalized()
	_match.get_node("Main/Territory").claim_cap(1, base_dir, 1.2)
	if not _check(await _wait(func(): return _solid_revealed().size() >= 5, 400), "poucos obstáculos revelados"): return
	await _wait(func(): return false, 90)   # deixa o crescimento (0,9 s) acabar

	# A boca do vulcão fica EM CIMA de um sólido; separa os sólidos em "dentro do solo escuro" e "fora"
	var solids := _solid_revealed()
	var spot: Vector3 = _slots._dirs[solids[0]]
	var mouth: Vector3 = _volcano.ground_point(spot)
	var radius: float = _volcano.soil_diameter * 0.5
	var inside := []
	var outside := []
	for i in solids:
		var d: float = (planet.center + _slots._dirs[i] * (mouth - planet.center).length()).distance_to(mouth)
		if d <= radius - 1.0:
			inside.append(i)
		elif d >= radius + 1.0:
			outside.append(i)
	print("obstáculos sólidos=%d  dentro do solo escuro=%d  fora=%d" % [solids.size(), inside.size(), outside.size()])
	if not _check(inside.size() >= 1 and outside.size() >= 3, "precisa de sólidos dentro e fora do solo escuro"): return
	var target: int = inside[0]
	var point: Vector3 = planet.center + _slots._dirs[target] * planet.radius

	await _bus.global_event_warning
	_volcano.plan(spot)
	if not _check(_slots._suppressed.is_empty(), "antes da erupção nada some"): return
	if not _check(await _wait(func(): return _volcano.state == ACTIVE, 400), "a erupção não começou"): return

	# Erupção: tudo em cima do solo escuro some e não colide; o de fora fica
	for i in inside:
		if not _check(_slots._suppressed.has(i), "obstáculo %d dentro do solo escuro deveria sumir" % i): return
	if not _check(await _wait(func(): return _slots._key[target] == -1, 400), "o obstáculo queimado deveria sumir da vista"): return
	if not _check(_slots.push_out(point, 0.6) == Vector3.ZERO, "obstáculo queimado não deve colidir"): return
	for i in outside:
		if not _check(not _slots._suppressed.has(i) and _slots._key[i] >= 0, "obstáculo %d fora do solo escuro não pode sumir" % i): return
	print("queimado: %d sumiram e não colidem; %d de fora continuam de pé" % [inside.size(), outside.size()])

	# Depois da cicatriz tudo volta
	if not _check(await _wait(func(): return _slots._key[target] >= 0, 1500), "o obstáculo queimado deveria voltar depois da cicatriz"): return
	if not _check(_slots.push_out(point, 0.6) != Vector3.ZERO, "o obstáculo que voltou deve colidir de novo"): return
	print("OK")
	quit(0)
