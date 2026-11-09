extends SceneTree
## Teste de fumaça do Passo 14 (SYS-004 / DD-107, o FURACÃO): (1) zonas Z1..Z4 pelos raios (20/45/70/100 % do raio);
## (2) corredor parado em Z3: é PUXADO para o olho, perde 1 pt/s, ao entrar em Z2 fica a -50 % de velocidade e,
## ao chegar em Z1, perde 4 pts e VOLTA À BASE; (3) corredor em Z4: é EMPURRADO para fora e não leva dano;
## (4) o furacão NASCE pequeno, CRESCE e ANDA; (5) cicatriz (poeira + destroços) + bônus raro, que some depois;
## (6) paz final. Tempos encurtados por exportação. Uso: godot_console --headless --path . -s res://tools/smoke_hurricane.gd

const ACTIVE := 3   # GlobalEvent.State (sem citar a classe em scripts -s)
const SCAR := 4

var _match: Node
var _bus: Node
var _storm: Node3D
var _runner: Node3D
var _health: Node
var _time := 0.0
var _warnings: Array = []
var _drops: Array = []
var _min_points := 16
var _min_dist := 1000.0
var _max_dist := 0.0
var _saw_slow := false
var _always_free := true
var _near_base := false
var _first_radius := -1.0
var _max_radius := 0.0
var _first_center := Vector3.ZERO
var _base_pos := Vector3.ZERO


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_storm = _match.get_node("Hurricane")
	_storm.min_seconds_between = 1.0
	_storm.max_seconds_between = 1.0
	_storm.quiet_after_start_seconds = 0.5
	_storm.warning_seconds = 1.5
	_storm.scar_seconds = 2.0
	_storm.storm_seconds = 6.0
	_storm.start_radius = 30.0   # ciclos 1 e 2: raio fixo e furacão parado
	_storm.full_radius = 30.0
	_storm.drift_speed = 0.0
	load("res://scripts/world/global_event.gd").gate_gap_seconds = 0.2   # DD-128: folga curta para os 3 ciclos caberem
	root.add_child(_match)
	_runner = _match.get_node("Main/Runner")
	_runner.move_speed = 0.0   # parado: quem o move é o furacão
	_health = _match.get_node("Main/Runner/Health")
	_bus = root.get_node("EventBus")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.bonus_drop_requested.connect(func(c, n): _drops.append([c, n]))
	_bus.health_changed.connect(func(_id, p, _m): _min_points = mini(_min_points, p))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _storm.state == ACTIVE:
		var d := _dist()
		_min_dist = minf(_min_dist, d)
		_max_dist = maxf(_max_dist, d)
		_saw_slow = _saw_slow or _runner.slow_multiplier == 0.5
		_always_free = _always_free and _runner.slow_multiplier == 1.0
		_near_base = _near_base or _runner.global_position.distance_to(_base_pos) < 5.0
		if _first_radius < 0.0:
			_first_radius = _storm.current_radius
			_first_center = _storm.center_dir
		_max_radius = maxf(_max_radius, _storm.current_radius)
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


func _dist() -> float:
	var radius: float = root.get_node("Services").planet.radius
	var unit := (_runner.global_position - _planet_center()).normalized()
	return acos(clampf(unit.dot(_storm.center_dir), -1.0, 1.0)) * radius


# Olho a `distance` u (pelo chão) do corredor.
func _eye_at(distance: float) -> Vector3:
	var up := (_runner.global_position - _planet_center()).normalized()
	var side := up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()
	return up.rotated(side, distance / root.get_node("Services").planet.radius)


func _reset_flags() -> void:
	_min_points = _health.points
	_min_dist = 1000.0
	_max_dist = 0.0
	_saw_slow = false
	_always_free = true
	_near_base = false
	_first_radius = -1.0
	_max_radius = 0.0


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var services: Node = root.get_node("Services")
	var civ_id: int = _match.get_node("Main/Runner/Civilization").id
	_base_pos = services.home_bases[civ_id]["position"]
	var antipode: Vector3 = _planet_center() - (_base_pos - _planet_center())
	var dust: Node3D = _storm.get_node("Dust")
	var funnel: Node3D = _storm.get_node("Funnel")
	var z1: Node3D = _storm.get_node("Z1")
	var z4: Node3D = _storm.get_node("Z4")
	_runner.teleport_to(antipode)

	# 1. Aviso: contagem + alvo no chão (sem funil); depois as zonas pelo raio (30: 6 / 13,5 / 21 / 30)
	await _bus.global_event_warning
	_storm.plan(_eye_at(18.0), Vector3.RIGHT)   # corredor em Z3
	await process_frame
	if not _check(z1.visible and z4.visible and not funnel.visible and not dust.visible, "no aviso só o alvo no chão"): return
	var zones := [_storm.zone_of(5.0), _storm.zone_of(10.0), _storm.zone_of(18.0), _storm.zone_of(25.0), _storm.zone_of(35.0)]
	if not _check(zones == [1, 2, 3, 4, 0], "zonas pelos raios: %s" % [zones]): return
	_reset_flags()

	# 2. Z3 → Z2 → Z1: puxa, 1 pt/s, -50 % em Z2, 4 pts + volta à base em Z1
	while _storm.state != SCAR:
		await process_frame
	if not _check(funnel.visible == false, "o funil some na cicatriz"): return
	if not _check(_min_dist < 7.0, "o corredor deveria ser sugado até o olho (%.1f)" % _min_dist): return
	if not _check(_saw_slow, "em Z2 a velocidade cai pela metade"): return
	if not _check(_near_base, "em Z1 volta à base"): return
	if not _check(_min_points <= 11, "dano de 1 pt/s + 4 do centro (menor vida: %d)" % _min_points): return
	if not _check(_runner.slow_multiplier == 1.0, "a lentidão termina com o furacão"): return
	if not _check(_warnings.map(func(w): return w[1]) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "FURACÃO SE FORMANDO", "nome do evento"): return

	# 3. Cicatriz: poeira + destroços + bônus raro; some depois
	if not _check(dust.visible and not z1.visible and not z4.visible, "cicatriz: só poeira e destroços"): return
	if not _check(_storm.get_node("Debris0").visible, "destroços no chão"): return
	if not _check(_drops.size() == 1 and _drops[0][1] >= 3 and _drops[0][1] <= 4, "bônus raro (3 a 4): %s" % [_drops]): return
	await _wait(2.4)
	if not _check(not dust.visible and not _storm.get_node("Debris0").visible, "a cicatriz deveria ter sumido"): return

	# 4. Z4: só empurra para fora, sem dano e sem lentidão
	_health.heal(16)
	_runner.teleport_to(antipode)
	_warnings.clear()
	await _bus.global_event_warning
	_storm.plan(_eye_at(25.0), Vector3.RIGHT)
	_reset_flags()
	while _storm.state != SCAR:
		await process_frame
	if not _check(_max_dist > 29.0, "Z4 empurra para fora (%.1f)" % _max_dist): return
	if not _check(_min_points == 16 and _always_free, "Z4 não fere nem atrasa (vida %d)" % _min_points): return
	if not _check(_warnings.size() == 3 and _warnings[0][1] == 2, "novo ciclo: %s" % [_warnings]): return

	# 5. Nasce pequeno, cresce e anda (corredor longe, só observamos o furacão)
	await _wait(2.4)
	_storm.start_radius = 8.0
	_storm.full_radius = 24.0
	_storm.drift_speed = 10.0
	_warnings.clear()
	await _bus.global_event_warning
	_storm.plan(-_eye_at(0.0), Vector3.RIGHT)   # olho do outro lado do planeta
	_reset_flags()
	while _storm.state != SCAR:
		await process_frame
	if not _check(_first_radius < 11.0, "nasce pequeno (%.1f)" % _first_radius): return
	if not _check(_max_radius > 23.0, "cresce (%.1f)" % _max_radius): return
	if not _check(_storm.center_dir.angle_to(_first_center) > 0.3, "anda pelo planeta (%.2f rad)" % _storm.center_dir.angle_to(_first_center)): return

	# 6. Paz final
	_storm.quiet_before_end_seconds = 100000.0
	await _wait(2.4 + 1.0 + 3.0)
	_warnings.clear()
	await _wait(4.0)
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
