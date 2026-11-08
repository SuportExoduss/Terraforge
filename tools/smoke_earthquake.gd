extends SceneTree
## Teste de fumaça do Passo 16 (SYS-004 / DD-107, o TERREMOTO): (1) aviso: rachaduras finas no chão, sem pedras;
## (2) rachadura aberta embaixo do corredor parado: 1 pt ao abrir + 2 pts ao fechar com ele dentro (PRESO);
## (3) pedra que cai em cima: 1 pt; (4) quem sai da rachadura antes de fechar só leva o 1 pt; (5) cicatriz: rachaduras
## finas + pedras no chão + cristais, que somem depois; (6) paz final. Tempos encurtados por exportação.
## Uso: godot_console --headless --path . -s res://tools/smoke_earthquake.gd

const ACTIVE := 3   # GlobalEvent.State (sem citar a classe em scripts -s)
const SCAR := 4

var _match: Node
var _bus: Node
var _quake: Node3D
var _runner: Node3D
var _health: Node
var _time := 0.0
var _warnings: Array = []
var _drops: Array = []
var _min_points := 16
var _points_mid := -1
var _open_mid := -1.0
var _leave_at := -1.0
var _away := Vector3.ZERO


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Bonuses").free()   # cristais caem junto do corredor parado: Vida Extra/Escudo sorteado falsearia a vida
	_quake =_match.get_node("Earthquake")
	_quake.min_seconds_between = 1.0
	_quake.max_seconds_between = 1.0
	_quake.quiet_after_start_seconds = 0.5
	_quake.warning_seconds = 1.5
	_quake.scar_seconds = 2.0
	_quake.quake_seconds = 1.0           # o fim real espera a última rachadura fechar
	_quake.open_seconds = 0.5
	_quake.first_close_seconds = 3.0
	_quake.close_gap_seconds = 0.5
	_quake.close_seconds = 1.0
	_quake.rock_interval = 0.5
	_quake.rock_fall_seconds = 0.6
	root.add_child(_match)
	_runner = _match.get_node("Main/Runner")
	_runner.move_speed = 0.0   # parado: quem sofre é o corredor
	_health = _match.get_node("Main/Runner/Health")
	_bus = root.get_node("EventBus")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.bonus_drop_requested.connect(func(c, n): _drops.append([c, n]))
	_bus.health_changed.connect(func(_id, p, _m): _min_points = mini(_min_points, p))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _quake.state == ACTIVE:
		if _points_mid < 0 and _quake.clock >= 2.5:   # rachaduras abertas, nenhuma fechou ainda
			_points_mid = _health.points
			_open_mid = _quake.open_amount(0)
		if _leave_at > 0.0 and _quake.clock >= _leave_at:
			_leave_at = -1.0
			_runner.teleport_to(_away)
	if _time > 150.0:
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


# Direção bem longe do corredor (a ~2,5 rad ou mais), diferente para cada i.
func _far(i: int) -> Vector3:
	var up := _up()
	var side := up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()
	return (-up).rotated(side, 0.1 * i)


func _fars(first: Vector3, count: int) -> Array:
	var list: Array = [first]
	for i in range(1, count):
		list.append(_far(i))
	return list


func _reset_flags() -> void:
	_min_points = _health.points
	_points_mid = -1
	_open_mid = -1.0


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
	var spot_up := _up()

	# 1. Aviso: rachaduras finas, sem pedras nem sombras; contagem 2-1-0
	await _bus.global_event_warning
	_quake.plan(_fars(spot_up, 6), _fars(-spot_up, 10))   # rachadura 0 embaixo do corredor; pedras longe
	await process_frame
	if not _check(_quake.get_node("Crack0_0").visible and _quake.get_node("Crack5_2").visible, "no aviso: rachaduras riscadas"): return
	if not _check(not _quake.get_node("Rock0").visible and not _quake.get_node("Mark0").visible, "no aviso: sem pedras nem sombras"): return
	if not _check(_quake.get_node("Crack0_0").scale.z < 0.5, "no aviso a rachadura ainda é fina"): return
	_reset_flags()

	# 2. Corredor sobre a rachadura: 1 pt ao abrir, +2 ao fechar com ele dentro; pedras longe não ferem
	while _quake.state != SCAR:
		await process_frame
	if not _check(_open_mid >= 0.99, "rachadura 0 aberta antes da hora de fechar (%.2f)" % _open_mid): return
	if not _check(_points_mid == 15, "aberta: só o 1 pt de tocar (vida %d)" % _points_mid): return
	if not _check(_min_points == 13, "preso: 1 + 2 pts (menor vida %d)" % _min_points): return
	if not _check(_warnings.map(func(w): return w[1]) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "TERREMOTO IMINENTE", "nome do evento"): return

	# 3. Cicatriz: rachaduras finas + pedras no chão + cristais; some depois
	if not _check(_quake.get_node("Crack0_0").visible and _quake.get_node("Crack0_0").scale.z < 0.5, "cicatriz: rachadura fina"): return
	if not _check(_quake.get_node("Rock0").visible and _quake.get_node("Rock9").visible, "cicatriz: pedras no chão"): return
	if not _check(not _quake.get_node("Mark0").visible, "cicatriz: sem sombras"): return
	if not _check(_drops.size() == 1 and _drops[0][1] >= 2 and _drops[0][1] <= 3, "cristais (2 a 3): %s" % [_drops]): return
	await _wait(2.4)
	if not _check(not _quake.get_node("Crack0_0").visible and not _quake.get_node("Rock0").visible, "a cicatriz deveria ter sumido"): return

	# 4. Pedra em cima do corredor: 1 pt (rachaduras longe)
	_health.heal(16)
	_runner.teleport_to(antipode)
	await process_frame
	await _bus.global_event_warning
	_quake.plan(_fars(-spot_up, 6), _fars(spot_up, 10))   # pedra 0 cai embaixo do corredor
	_reset_flags()
	while _quake.state != SCAR:
		await process_frame
	if not _check(_min_points == 15, "pedra: 1 pt (menor vida %d)" % _min_points): return
	await _wait(2.4)

	# 5. Sai da rachadura antes de fechar: só o 1 pt de tocar
	_health.heal(16)
	_runner.teleport_to(antipode)
	await process_frame
	var up := _up()   # 90° do corredor: longe das rachaduras (que ficam perto de -up) e da pedra
	var sideways := up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()
	_away = _planet_center() + sideways * services.planet.get_surface_radius(sideways)
	await _bus.global_event_warning
	_quake.plan(_fars(spot_up, 6), _fars(-spot_up, 10))
	_reset_flags()
	_leave_at = 2.0   # rachadura já aberta (0,5 s) e longe do 1º fechamento (3 s)
	while _quake.state != SCAR:
		await process_frame
	if not _check(_min_points == 15, "quem sai a tempo só leva 1 pt (menor vida %d)" % _min_points): return

	# 6. Paz final
	_quake.quiet_before_end_seconds = 100000.0
	await _wait(2.4 + 1.0 + 3.0)
	_warnings.clear()
	await _wait(4.0)
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
