extends SceneTree
## Teste de fumaça do Passo 9 (SYS-006 Defensores): (1) cada civilização ganha sentinela(s), dentro do teto;
## (2) patrulham sem nunca sair do próprio território; (3) um invasor é avisado (ALERTA), perseguido e atacado
## com golpe de 2 pontos (DD-109) e recarga (sem matar de uma vez), e o dono nunca é ferido; (4) invasor que sai do
## território é largado (RETORNO). Uso: godot_console --headless --path . -s res://tools/smoke_defenders.gd

const PATROL := 0   # = DefenderSystem.State (a classe não é citada: no modo -s ela compilaria antes dos autoloads)
const ALERT := 1
const CHASE := 2
const ATTACK := 3
const RETURN := 4
const REST := 5

var _match: Node
var _bus: Node
var _services: Node
var _defenders: Node
var _time := 0.0
var _dt := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_services = root.get_node("Services")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	_dt = delta
	if _time > 40.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _guards_of(id: int) -> Array:
	return _defenders._guards.filter(func(g): return g.owner_id == id)


func _all_inside() -> bool:
	for g in _defenders._guards:
		if not _services.territory.is_owned_by(g.owner_id, g.position):
			return false
	return true


func _run() -> void:
	await _bus.match_started
	for i in 5:
		await process_frame
	_defenders = _match.get_node("Defenders")
	var runner1: Node3D = _match.get_node("Main/Runner")
	var runner2: Node3D = _match.get_node("Main/Runner2")
	var health1: Node = runner1.get_node("Health")
	var health2: Node = runner2.get_node("Health")
	runner1.set_process(false)
	runner2.set_process(false)

	# 1. Uma (no mínimo) por civilização, dentro do teto
	for id in [1, 2]:
		var n := _guards_of(id).size()
		if not _check(n >= 1 and n <= _defenders.max_per_civilization, "civ %d com %d sentinelas" % [id, n]): return

	# 2. Patrulha: 2 s sem sair do território
	for i in 120:
		await process_frame
		if not _check(_all_inside(), "sentinela saiu do território na patrulha"): return

	# 3. Invasor: runner2 pisa na base da civ 1
	var base: Vector3 = _services.home_bases[1]["position"]
	var up: Vector3 = (base - _services.planet.center).normalized()
	var side: Vector3 = up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD).normalized()
	var spot: Vector3 = base + side * 5.0
	var dir: Vector3 = (spot - _services.planet.center).normalized()
	runner2.teleport_to(_services.planet.center + dir * _services.planet.get_surface_radius(dir))
	if not _check(_services.territory.is_owned_by(1, runner2.global_position), "o ponto do invasor deveria ser da civ 1"): return
	var seen := {}
	var hit_at := -1.0
	var t := 0.0
	while t < 12.0 and health2.points == 16:
		await process_frame
		t += _dt
		for g in _guards_of(1):
			seen[g.state] = true
		if not _check(_all_inside(), "sentinela saiu do território na perseguição"): return
	if not _check(health2.points == 14, "primeiro golpe tira exatamente 2 pontos (%d)" % health2.points): return
	if not _check(seen.has(ALERT) and seen.has(CHASE), "deveria ter passado por ALERTA e PERSEGUIÇÃO (%s)" % [seen.keys()]): return
	if not _check(health1.points == 16, "o dono nunca é ferido (%d)" % health1.points): return
	hit_at = t
	# recarga: 1 s depois ainda 14 (cooldown 2 s)
	while t < hit_at + 1.0:
		await process_frame
		t += _dt
	if not _check(health2.points == 14, "recarga do golpe (%d)" % health2.points): return

	# 3b. DD-109: perseguição máxima de 4 s. O invasor fica parado ao lado do touro: sem o teto, CHASE/ATTACK seria contínuo.
	var run := {}
	var longest := 0.0
	var tt := 0.0
	while tt < 9.0:
		await process_frame
		tt += _dt
		for g in _guards_of(1):
			if g.state == CHASE or g.state == ATTACK:
				run[g] = run.get(g, 0.0) + _dt
				longest = maxf(longest, run[g])
			else:
				run[g] = 0.0
	if not _check(longest <= 5.2, "perseguição contínua de %.1f s (DD-109: máximo 4 s, mais o golpe em curso)" % longest): return

	# 4. Invasor foge para terra de ninguém: sentinelas largam a caça
	var far: Vector3 = _services.territory.get_random_unowned_position()
	runner2.teleport_to(far)
	var hp_before: int = health2.points
	if not _check(not _services.territory.is_owned_by(1, runner2.global_position), "ponto fugido deveria ser livre"): return
	for i in 30:
		await process_frame
	for g in _guards_of(1):
		if not _check(g.state in [RETURN, REST, PATROL], "sentinela ainda caçando fora do território (estado %d)" % g.state): return
	if not _check(health2.points >= hp_before, "sem golpes fora do território (%d < %d)" % [health2.points, hp_before]): return
	print("OK")
	quit(0)
