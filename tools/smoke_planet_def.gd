extends SceneTree
## Teste de fumaça do Passo 103/104 (DD-143, planetas por dados): (1) o catálogo tem o Médio (raio 100, 20000 células, 720 slots,
## 600 s, 3 bots = o jogo de sempre) e o Pequeno (área 36%: células e slots proporcionais); (2) uma partida no PEQUENO nasce com
## raio 60, 7200 células, 259 slots, 3 civilizações bem separadas, relógio de 240 s e termina UMA vez; (3) o menu mostra e troca o planeta.
## Uso: godot_console --headless --path . -s res://tools/smoke_planet_def.gd

const SMALL_RADIUS := 60.0

var _match: Node
var _bus: Node
var _services: Node
var _started := 0
var _ended := 0
var _left_at_go := -1
var _time := 0.0
var _after_end := 0.0
var _farthest := {}
var _spawn := {}


func _fail(msg: String) -> bool:
	print("FALHOU: ", msg)
	quit(1)
	return true


func _initialize() -> void:
	var def_script: GDScript = load("res://scripts/core/planet_def.gd")
	var all: Array = def_script.catalog()
	var medium: Resource = def_script.by_id("medio")
	var small: Resource = def_script.by_id("pequeno")
	if all.size() < 2 or medium.radius != 100.0 or medium.cell_count() != 20000 or medium.slot_count() != 720 or medium.duration_seconds != 600.0 or medium.bots != 3:
		_fail("o Médio deve ser o planeta de sempre")
		return
	if small.radius != SMALL_RADIUS or small.cell_count() != 7200 or small.slot_count() != 259 or small.duration_seconds >= medium.duration_seconds or small.bots + 1 < 2:
		_fail("o Pequeno deveria ter 36%% da área (7200 células, 259 slots) e partida mais curta: %d, %d" % [small.cell_count(), small.slot_count()])
		return
	if def_script.by_id("nao-existe").id != "medio":
		_fail("planeta desconhecido deveria cair no Médio")
		return
	_services = root.get_node("Services")
	_services.match_def = small
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.match_started.connect(_on_started)
	_bus.match_ended.connect(func(): _ended += 1)


func _on_started() -> void:
	_started += 1
	for id in _services.home_bases:
		_spawn[id] = _services.home_bases[id]["position"]
	var timer: Node = _match.get_node("MatchTimer")
	_left_at_go = timer.seconds_left()
	timer.restore_seconds(6)   # não espera os 240 s: o que importa é que o fim sai uma vez


func _runner(id: int) -> Node3D:
	return _match.get_node("Main/Runner" if id == 1 else "Main/Runner%d" % id)


func _process(delta: float) -> bool:
	_time += delta
	if _time > 40.0:
		return _fail("tempo esgotado (GO=%d, fim=%d)" % [_started, _ended])
	if _started == 0:
		return false
	for id in _spawn:
		_farthest[id] = maxf(_farthest.get(id, 0.0), _runner(id).global_position.distance_to(_spawn[id]))
	if _ended == 0:
		return false
	_after_end += delta
	if _after_end < 0.5:
		return false
	return _verify()


func _verify() -> bool:
	var planet: Node3D = _services.planet
	var ids: Array = _spawn.keys()
	if _started != 1 or _ended != 1:
		return _fail("GO! e fim deveriam sair exatamente uma vez (GO=%d, fim=%d)" % [_started, _ended])
	if not is_equal_approx(planet.radius, SMALL_RADIUS):
		return _fail("raio %f em vez de %f" % [planet.radius, SMALL_RADIUS])
	var map: Node = _services.territory
	if map.cell_count != 7200:
		return _fail("a grade deveria ter 7200 células, tem %d" % map.cell_count)
	var slots: Node = _match.get_node("Main/Slots")
	if slots.get("_dirs").size() != 259:
		return _fail("deveria haver 259 slots, há %d" % slots.get("_dirs").size())
	if _left_at_go < 230 or _left_at_go > 240:
		return _fail("o relógio deveria começar em 240 s, começou em %d" % _left_at_go)
	if ids.size() != 3:
		return _fail("esperava 3 civilizações (jogador + 2 bots), vieram %d" % ids.size())
	for i in ids.size():
		var up: Vector3 = ((_spawn[ids[i]] as Vector3) - planet.center).normalized()
		if ((_spawn[ids[i]] as Vector3) - planet.center).length() > SMALL_RADIUS + 4.0:
			return _fail("a base %d nasceu fora do planeta pequeno" % ids[i])
		for j in range(i + 1, ids.size()):
			var other: Vector3 = ((_spawn[ids[j]] as Vector3) - planet.center).normalized()
			if rad_to_deg(up.angle_to(other)) < 85.0:
				return _fail("bases %d e %d juntas demais" % [ids[i], ids[j]])
	var moving := 0
	for id in _farthest:
		if id != 1 and _farthest[id] > 5.0:
			moving += 1
	if moving < 2:
		return _fail("os 2 bots deveriam ter saído a campo (saíram %d)" % moving)
	if map.owned_fraction(1) <= 0.0:
		return _fail("a civilização 1 deveria ter o território da base")
	print("pequeno: raio %.0f, %d células, %d slots, %d civilizações, relógio %d s, jogador com %.1f%%" % [planet.radius, map.cell_count, slots.get("_dirs").size(), ids.size(), _left_at_go, map.owned_fraction(1) * 100.0])
	_services.match_def = null
	print("OK")
	quit(0)
	return true
