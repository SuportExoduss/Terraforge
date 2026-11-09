extends SceneTree
## Teste de fumaça do Passo 15 (SYS-004 / DD-107, a CHUVA ÁCIDA): (1) aviso: nuvens + mancha verde no chão, sem chuva;
## (2) corredor EXPOSTO (parado, fora de qualquer território): 1 pt/s; fora da área: nada; (3) corredor no PRÓPRIO
## TERRITÓRIO: metade do dano; (4) cicatriz: plantas queimadas + flores + bônus raro, que some depois; (5) a área ANDA;
## (6) paz final. Tempos encurtados por exportação. Uso: godot_console --headless --path . -s res://tools/smoke_acid_rain.gd

const ACTIVE := 3   # GlobalEvent.State (sem citar a classe em scripts -s)
const SCAR := 4

var _match: Node
var _bus: Node
var _rain: Node3D
var _runner: Node3D
var _health: Node
var _time := 0.0
var _warnings: Array = []
var _drops: Array = []
var _min_points := 16
var _rain_always_visible := true
var _first_center := Vector3.ZERO
var _last_center := Vector3.ZERO
var _seen_active := false


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_rain = _match.get_node("AcidRain")
	_rain.min_seconds_between = 1.0
	_rain.max_seconds_between = 1.0
	_rain.quiet_after_start_seconds = 0.5
	_rain.warning_seconds = 1.5
	_rain.scar_seconds = 2.0
	_rain.rain_seconds = 6.0
	_rain.rain_radius = 40.0
	_rain.drift_speed = 0.0
	load("res://scripts/world/global_event.gd").gate_gap_seconds = 0.2   # DD-128: folga curta, o teste repete ciclos
	root.add_child(_match)
	_runner = _match.get_node("Main/Runner")
	_runner.move_speed = 0.0   # parado: quem sofre é o corredor, não o mapa
	_health = _match.get_node("Main/Runner/Health")
	_bus = root.get_node("EventBus")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.bonus_drop_requested.connect(func(c, n): _drops.append([c, n]))
	_bus.health_changed.connect(func(_id, p, _m): _min_points = mini(_min_points, p))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _rain.state == ACTIVE:
		_rain_always_visible = _rain_always_visible and _rain.get_node("Drop0").visible
		if not _seen_active:
			_seen_active = true
			_first_center = _rain.center_dir
		_last_center = _rain.center_dir
	if _time > 120.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _planet_center() -> Vector3:
	return root.get_node("Services").planet.center


func _up() -> Vector3:
	return (_runner.global_position - _planet_center()).normalized()


func _reset_flags() -> void:
	_min_points = _health.points
	_rain_always_visible = true
	_seen_active = false


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var services: Node = root.get_node("Services")
	var civ_id: int = _match.get_node("Main/Runner/Civilization").id
	var base_pos: Vector3 = services.home_bases[civ_id]["position"]
	var antipode: Vector3 = _planet_center() - (base_pos - _planet_center())
	_runner.teleport_to(antipode)
	await process_frame
	if not _check(not services.territory.is_owned_by(civ_id, _runner.global_position), "o antípoda deveria ser território livre"): return

	# 1. Aviso: nuvens + mancha verde, sem chuva; contagem 2-1-0; área certa
	await _bus.global_event_warning
	_rain.plan(-_up(), Vector3.RIGHT)   # área do outro lado: o corredor está fora
	await process_frame
	if not _check(_rain.get_node("Cloud0").visible and _rain.get_node("Patch0").visible and not _rain.get_node("Drop0").visible, "no aviso: nuvens e mancha, sem chuva"): return
	if not _check(_rain.rate_for(_runner) == 0.0, "fora da área não há dano"): return
	_rain.plan(_up(), Vector3.RIGHT)
	await process_frame
	if not _check(_rain.rate_for(_runner) == 1.0, "exposto = 1 pt/s (%.2f)" % _rain.rate_for(_runner)): return
	_reset_flags()

	# 2. Exposto: ~1 pt/s durante 6 s
	while _rain.state != SCAR:
		await process_frame
	var lost_exposed: int = 16 - _min_points
	if not _check(lost_exposed >= 4 and lost_exposed <= 7, "exposto deveria perder ~6 pts (perdeu %d)" % lost_exposed): return
	if not _check(_rain_always_visible, "a chuva fica visível durante a execução"): return
	if not _check(_warnings.map(func(w): return w[1]) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "CHUVA ÁCIDA SE APROXIMANDO", "nome do evento"): return

	# 3. Cicatriz: plantas queimadas + flores + bônus raro; some depois
	if not _check(not _rain.get_node("Cloud0").visible and not _rain.get_node("Drop0").visible, "cicatriz: sem nuvens nem chuva"): return
	if not _check(_rain.get_node("Burned0").visible and _rain.get_node("Flower0").visible, "plantas queimadas e flores"): return
	if not _check(_drops.size() == 1 and _drops[0][1] >= 3 and _drops[0][1] <= 4, "bônus raro (3 a 4): %s" % [_drops]): return
	await _wait(2.4)
	if not _check(not _rain.get_node("Burned0").visible and not _rain.get_node("Flower0").visible and not _rain.get_node("Patch0").visible, "a cicatriz deveria ter sumido"): return

	# 4. No PRÓPRIO território: metade do dano (a mesma chuva e o mesmo tempo, menos pontos perdidos)
	_health.heal(16)
	services.territory.claim_cap(civ_id, _up(), 0.6)
	await process_frame
	if not _check(services.territory.is_owned_by(civ_id, _runner.global_position), "o corredor deveria estar em território próprio"): return
	await _bus.global_event_warning
	_rain.plan(_up(), Vector3.RIGHT)
	await process_frame
	if not _check(_rain.rate_for(_runner) == 0.5, "território próprio = 50 %% (%.2f)" % _rain.rate_for(_runner)): return
	_reset_flags()
	while _rain.state != SCAR:
		await process_frame
	var lost_own: int = 16 - _min_points
	if not _check(lost_own >= 2 and lost_own <= 4, "no próprio território deveria perder ~3 pts (perdeu %d)" % lost_own): return
	if not _check(lost_own < lost_exposed, "território próprio perde menos que exposto (%d x %d)" % [lost_own, lost_exposed]): return

	# 5. A área anda (corredor fora dela, só observamos)
	await _wait(2.4)
	_rain.drift_speed = 10.0
	await _bus.global_event_warning
	_rain.plan(-_up(), Vector3.RIGHT)
	_health.heal(16)
	_reset_flags()
	while _rain.state != SCAR:
		await process_frame
	var moved: float = _first_center.angle_to(_last_center)
	if not _check(moved > 0.3, "a chuva deveria andar pelo planeta (%.2f rad)" % moved): return
	if not _check(_min_points == 16, "fora da área não há dano (vida %d)" % _min_points): return

	# 6. Paz final
	_rain.quiet_before_end_seconds = 100000.0
	await _wait(2.4 + 1.0 + 3.0)
	_warnings.clear()
	await _wait(4.0)
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
