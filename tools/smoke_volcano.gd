extends SceneTree
## Teste de fumaça do Passo 13 (SYS-004 / DD-107, o VULCÃO): (1) regra das bolas: cada uma tira 1 ponto e a 4ª
## ACUMULADA devolve o corredor à base (e o contador zera); (2) AVISO: contagem 2,1,0 + chão escurecido e cone baixo;
## (3) EXECUÇÃO: o cone sobe, bolas voam com a mancha de queda e a lava atinge quem está embaixo; (4) CICATRIZ:
## cone afunda, solo escuro + lava sólida + cristais (bônus) e tudo some; (5) erupção longe do corredor não fere;
## (6) na paz final nada vem. Tempos encurtados por exportação.
## Uso: godot_console --headless --path . -s res://tools/smoke_volcano.gd

const ACTIVE := 3   # GlobalEvent.State (sem citar a classe em scripts -s)
const SCAR := 4

var _match: Node
var _bus: Node
var _volcano: Node3D
var _runner: Node3D
var _time := 0.0
var _warnings: Array = []
var _drops: Array = []
var _min_points := 16
var _saw_ball := false
var _saw_mark := false
var _cone_top := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_volcano = _match.get_node("Volcano")
	_volcano.min_seconds_between = 1.0
	_volcano.max_seconds_between = 1.0
	_volcano.quiet_after_start_seconds = 0.5
	_volcano.warning_seconds = 2.0
	_volcano.scar_seconds = 4.0
	_volcano.eruption_seconds = 4.0
	_volcano.launch_interval = 0.5
	_volcano.flight_seconds = 0.6
	root.add_child(_match)
	_runner = _match.get_node("Main/Runner")
	_runner.move_speed = 0.0   # parado: o teste controla onde a lava cai
	_bus = root.get_node("EventBus")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.bonus_drop_requested.connect(func(c, n): _drops.append([c, n]))
	_bus.health_changed.connect(func(_id, p, _m): _min_points = mini(_min_points, p))
	_run()


func _process(_delta: float) -> bool:
	_time += _delta
	if _volcano.state == ACTIVE:
		for i in 6:
			_saw_ball = _saw_ball or _volcano.get_node("Ball%d" % i).visible
			_saw_mark = _saw_mark or _volcano.get_node("Mark%d" % i).visible
		_cone_top = maxf(_cone_top, _volcano.get_node("Cone").scale.y)
	if _time > 90.0:
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
	return (_runner.global_position - root.get_node("Services").planet.center).normalized()


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var services: Node = root.get_node("Services")
	var planet: Node = services.planet
	var health: Node = _match.get_node("Main/Runner/Health")
	var civ_id: int = _match.get_node("Main/Runner/Civilization").id
	var base_pos: Vector3 = services.home_bases[civ_id]["position"]
	var antipode: Vector3 = planet.center - (base_pos - planet.center)
	var soil: Node3D = _volcano.get_node("Soil")
	var lava: Node3D = _volcano.get_node("Lava")
	var cone: Node3D = _volcano.get_node("Cone")

	# 1. Regra das bolas: 1 ponto cada; a 4ª acumulada = volta à base e o contador zera
	_runner.teleport_to(antipode)
	health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	for i in 3:
		_volcano.hit(_runner)
	if not _check(health.points == 13, "3 bolas = -3 (%d)" % health.points): return
	if not _check(_runner.global_position.distance_to(base_pos) > 50.0, "3 bolas ainda não mandam para a base"): return
	_volcano.hit(_runner)
	if not _check(health.points == 12, "4ª bola = -1 (%d)" % health.points): return
	if not _check(_runner.global_position.distance_to(base_pos) < 5.0, "4ª bola manda para a base (%.1f u)" % _runner.global_position.distance_to(base_pos)): return
	_runner.teleport_to(antipode)
	for i in 3:
		_volcano.hit(_runner)
	if not _check(_runner.global_position.distance_to(base_pos) > 50.0, "o contador zera depois da volta à base"): return
	health.heal(16)
	_runner.teleport_to(antipode)
	_warnings.clear()

	# 2. Aviso: contagem + chão escurecendo + cone baixo (a boca fica EM CIMA do corredor, e as bolas o acertam)
	_volcano.hit_radius = 200.0   # ciclo 1: qualquer queda acerta o corredor
	await _bus.global_event_warning
	_volcano.plan(_up())
	await process_frame
	if not _check(soil.visible and cone.visible and not lava.visible, "no aviso: solo e cone, sem lava"): return
	var small: float = soil.scale.x
	if not _check(cone.scale.y < 3.0, "o cone começa baixo (%.2f)" % cone.scale.y): return
	await _wait(1.0)
	if not _check(soil.scale.x > small + 1.0, "o solo deveria escurecer mais (%.1f → %.1f)" % [small, soil.scale.x]): return
	_min_points = health.points

	# 3. Execução: cone sobe, bolas voam com mancha, a lava fere
	while _volcano.state != SCAR:
		await process_frame
	if not _check(_cone_top > 6.0, "o cone deveria subir (%.1f)" % _cone_top): return
	if not _check(_saw_ball and _saw_mark, "bolas e manchas de queda deveriam aparecer (%s/%s)" % [_saw_ball, _saw_mark]): return
	if not _check(_min_points < 16, "a lava deveria ferir (menor vida vista: %d)" % _min_points): return
	if not _check(_warnings.map(func(w): return w[1]) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "VULCÃO EM ERUPÇÃO", "nome do evento"): return

	# 4. Cicatriz: solo escuro + lava sólida + cristais; o cone afunda; depois tudo some
	if not _check(lava.visible and soil.visible, "cicatriz: solo e lava"): return
	for i in 6:
		if not _check(not _volcano.get_node("Ball%d" % i).visible, "bolas somem na cicatriz"): return
	if not _check(_drops.size() == 1 and _drops[0][1] >= 2 and _drops[0][1] <= 3, "2 a 3 cristais: %s" % [_drops]): return
	var at: Vector3 = (_drops[0][0] as Vector3) - planet.center
	if not _check(absf(at.length() - planet.get_surface_radius(at.normalized())) < 0.01, "cristais fora do chão"): return
	await _wait(1.0)
	if not _check(not cone.visible, "o cone deveria ter afundado"): return
	await _wait(3.4)
	if not _check(not soil.visible and not lava.visible, "a cicatriz deveria ter secado"): return

	# 5. Erupção longe do corredor não fere (raio de queda normal, 3 u)
	health.heal(16)
	_runner.teleport_to(antipode)
	_volcano.hit_radius = 3.0
	_warnings.clear()
	await _bus.global_event_warning
	_volcano.plan(-_up())   # do outro lado: as bolas caem a até 38 u da boca, a runner está a ~200 u
	_min_points = health.points
	while _volcano.state != SCAR:
		await process_frame
	if not _check(_min_points == 16, "lava distante não fere (menor vida vista: %d)" % _min_points): return
	if not _check(_warnings.size() == 3 and _warnings[0][1] == 2, "o ciclo recomeça com a contagem em 2: %s" % [_warnings]): return

	# 6. Paz final
	_volcano.quiet_before_end_seconds = 100000.0
	await _wait(4.4 + 1.0 + 3.0)   # cicatriz + espera + folga
	_warnings.clear()
	await _wait(4.0)
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
