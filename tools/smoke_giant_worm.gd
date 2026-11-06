extends SceneTree
## Teste de fumaça do Passo 17 (SYS-004 / DD-107, o VERME GIGANTE): (1) aviso: 6 a 10 saltos sorteados, nada visível,
## contagem 2-1-0; (2) o chão incha antes de explodir (monte e anéis visíveis, ninguém ferido, verme escondido);
## (3) em cima: 4 pts + volta à base; (4) perto: 2 pts; (5) borda: 1 pt; (6) fora da zona: 0; (7) três saltos seguidos:
## 3 explosões, 3 montes + 3 buracos, cristais, e tudo some depois; (8) paz final. Tempos encurtados por exportação.
## Uso: godot_console --headless --path . -s res://tools/smoke_giant_worm.gd

const ACTIVE := 3   # GlobalEvent.State (sem citar a classe em scripts -s)
const SCAR := 4

var _match: Node
var _bus: Node
var _worm: Node3D
var _runner: Node3D
var _health: Node
var _services: Node
var _antipode := Vector3.ZERO
var _base_pos := Vector3.ZERO
var _time := 0.0
var _warnings: Array = []
var _drops: Array = []
var _strikes: Array = []
var _min_points := 16
var _points_swell := -1
var _clock_swell := -1.0
var _swell_ok := false
var _mound_y_swell := -1.0
var _worm_seen := false


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_worm = _match.get_node("GiantWorm")
	_worm.min_seconds_between = 1.0
	_worm.max_seconds_between = 1.0
	_worm.quiet_after_start_seconds = 0.5
	_worm.warning_seconds = 1.5
	_worm.scar_seconds = 2.0
	_worm.swell_seconds = 0.8
	_worm.burst_seconds = 0.3
	_worm.dive_seconds = 0.3
	_worm.gap_seconds = 0.3
	root.add_child(_match)
	_runner = _match.get_node("Main/Runner")
	_runner.move_speed = 0.0   # parado: quem sofre é o corredor
	_health = _match.get_node("Main/Runner/Health")
	_bus = root.get_node("EventBus")
	_services = root.get_node("Services")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.bonus_drop_requested.connect(func(c, n): _drops.append([c, n]))
	_bus.radial_damage.connect(func(c, ir, id, back, mr, md, orad, od): _strikes.append([c, ir, id, back, mr, md, orad, od]))
	_bus.health_changed.connect(func(_id, p, _m): _min_points = mini(_min_points, p))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _worm.state == ACTIVE:
		if _points_swell < 0 and _worm.clock >= 0.4:   # no meio do 1º inchaço
			_points_swell = _health.points
			_clock_swell = _worm.clock
			_swell_ok = _worm.get_node("Mound0").visible and _worm.get_node("Zone0").visible and not _worm.get_node("Worm").visible
			_mound_y_swell = _worm.get_node("Mound0").scale.y
		if _worm.get_node("Worm").visible:
			_worm_seen = true
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


func _up() -> Vector3:
	return (_runner.global_position - _services.planet.center).normalized()


func _side(up: Vector3) -> Vector3:
	return up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()


# Direção a `offset` u (pelo chão) do corredor.
func _aim(offset: float) -> Vector3:
	var up := _up()
	return up.rotated(_side(up), offset / _services.planet.radius)


# Direção bem longe do corredor, diferente para cada i.
func _far(i: int) -> Vector3:
	var up := _up()
	return (-up).rotated(_side(up), 0.1 * i)


func _arm(targets: Array, count: int) -> void:
	_worm.plan(targets, count)
	_strikes.clear()
	_drops.clear()
	_min_points = _health.points
	_points_swell = -1
	_clock_swell = -1.0
	_swell_ok = false
	_mound_y_swell = -1.0
	_worm_seen = false


func _until_scar() -> void:
	while _worm.state != SCAR:
		await process_frame


# Um ciclo com um salto só, `offset` u do corredor; devolve a menor vida vista.
func _cycle(offset: float) -> int:
	_health.heal(16)
	_runner.teleport_to(_antipode)
	await process_frame
	await _bus.global_event_warning
	_arm([_aim(offset)], 1)
	await _until_scar()
	var lowest := _min_points
	await _wait(2.4)   # a cicatriz some
	return lowest


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var civ_id: int = _match.get_node("Main/Runner/Civilization").id
	_base_pos = _services.home_bases[civ_id]["position"]
	var center: Vector3 = _services.planet.center
	_antipode = center - (_base_pos - center)
	_runner.teleport_to(_antipode)
	await process_frame

	# 1. Aviso: 6 a 10 saltos sorteados, nada visível; depois 1 salto exatamente sobre o corredor
	await _bus.global_event_warning
	if not _check(_worm.jump_count >= 6 and _worm.jump_count <= 10, "saltos sorteados de 6 a 10 (%d)" % _worm.jump_count): return
	await process_frame
	if not _check(not _worm.get_node("Mound0").visible and not _worm.get_node("Zone0").visible and not _worm.get_node("Worm").visible, "no aviso o verme está debaixo da terra"): return
	_arm([_aim(0.0)], 1)
	await _until_scar()

	# 2. Inchaço: monte e anéis à vista, ninguém ferido, verme ainda escondido
	if not _check(_swell_ok, "no inchaço: monte e anéis visíveis, verme escondido"): return
	if not _check(_points_swell == 16, "o inchaço não fere (vida %d)" % _points_swell): return
	if not _check(_clock_swell < _worm.swell_seconds, "amostra dentro do inchaço (%.2f)" % _clock_swell): return
	if not _check(_mound_y_swell > 0.0 and _mound_y_swell < _worm.MOUND_SIZE.y * 0.95, "o monte está crescendo (%.2f)" % _mound_y_swell): return

	# 3. Em cima: 4 pts + volta à base; o verme apareceu; mesmo sinal do meteoro
	if not _check(_min_points == 12, "em cima: 4 pts (menor vida %d)" % _min_points): return
	if not _check(_runner.global_position.distance_to(_base_pos) < 8.0, "em cima: volta ao campo de força"): return
	if not _check(_worm_seen, "o verme irrompeu"): return
	if not _check(_strikes.size() == 1, "uma explosão (%d)" % _strikes.size()): return
	var strike: Array = _strikes[0]
	if not _check(strike[1] == _worm.inner_radius and strike[2] == 4 and strike[3] and strike[5] == 2 and strike[7] == 1, "anéis 4+base / 2 / 1: %s" % [strike]): return
	if not _check(_warnings.map(func(w): return w[1]) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "VERME GIGANTE IMINENTE", "nome do evento"): return
	if not _check(_worm.get_node("Mound0").visible and _worm.get_node("Mound0").scale.y > _worm.MOUND_SIZE.y * 0.85, "cicatriz: monte cheio"): return
	if not _check(_worm.get_node("Hole0").visible, "cicatriz: buraco do túnel"): return
	if not _check(not _worm.get_node("Zone0").visible and not _worm.get_node("Worm").visible, "cicatriz: sem anéis nem verme"): return
	if not _check(_drops.size() == 1 and _drops[0][1] >= 2 and _drops[0][1] <= 3, "cristais (2 a 3): %s" % [_drops]): return
	await _wait(2.4)
	if not _check(not _worm.get_node("Mound0").visible and not _worm.get_node("Hole0").visible, "a cicatriz deveria ter sumido"): return

	# 4. Perto, borda e fora da zona (o corredor volta ao ponto de teste a cada ciclo)
	var near := await _cycle(4.5)
	if not _check(near == 14, "perto: 2 pts (menor vida %d)" % near): return
	if not _check(_runner.global_position.distance_to(_antipode) < 3.0, "perto: não volta à base"): return
	var edge := await _cycle(7.5)
	if not _check(edge == 15, "borda: 1 pt (menor vida %d)" % edge): return
	var outside := await _cycle(12.0)
	if not _check(outside == 16, "fora da zona: 0 pt (menor vida %d)" % outside): return

	# 5. Três saltos seguidos longe do corredor: 3 explosões, 3 montes + 3 buracos, cristais
	_health.heal(16)
	_runner.teleport_to(_antipode)
	await process_frame
	await _bus.global_event_warning
	_arm([_far(0), _far(1), _far(2)], 3)
	await _until_scar()
	if not _check(_strikes.size() == 3, "3 explosões (%d)" % _strikes.size()): return
	if not _check(_min_points == 16, "saltos longe não ferem (menor vida %d)" % _min_points): return
	if not _check(_worm_seen, "o verme irrompeu nos 3 saltos"): return
	if not _check(_worm.get_node("Mound2").visible and _worm.get_node("Hole2").visible, "3 montes e buracos"): return
	if not _check(not _worm.get_node("Mound3").visible and not _worm.get_node("Hole3").visible, "só 3 montes e buracos"): return
	if not _check(_drops.size() == 1 and _drops[0][1] >= 2 and _drops[0][1] <= 3, "cristais (2 a 3): %s" % [_drops]): return
	await _wait(2.4)
	if not _check(not _worm.get_node("Mound2").visible and not _worm.get_node("Hole2").visible, "a cicatriz deveria ter sumido"): return

	# 6. Paz final
	_worm.quiet_before_end_seconds = 100000.0
	await _wait(1.0 + 3.0)
	_warnings.clear()
	await _wait(4.0)
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
