extends SceneTree
## Teste de fumaça do 6b (partida): (1) 4 civilizações nascem nas faces do cubo inclinado — fora dos polos,
## bem separadas; (2) o GO! sai uma vez, com todas as naves pousadas; (3) os bots saem a campo e se movem;
## (4) o relógio conta segundo a segundo e a partida termina UMA vez; (5) depois do fim todos param.
## Uso: godot_console --headless --path . -s res://tools/smoke_match.gd

const MATCH_SECONDS := 12.0

var _bus: Node
var _match: Node
var _started := 0
var _ended := 0
var _clock: Array[int] = []
var _spawn: Dictionary = {}       # id -> posição no GO!
var _farthest: Dictionary = {}    # id -> maior distância já percorrida a partir do spawn
var _time := 0.0
var _after_end := 0.0
var _frozen_at := {}


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchTimer").duration_seconds = MATCH_SECONDS
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.match_started.connect(_on_started)
	_bus.match_ended.connect(func(): _ended += 1)
	_bus.match_clock_changed.connect(func(s): _clock.append(s))


func _fail(msg: String) -> bool:
	print("FALHOU: ", msg)
	quit(1)
	return true


func _on_started() -> void:
	_started += 1
	var services: Node = root.get_node("Services")
	for id in services.home_bases:
		_spawn[id] = services.home_bases[id]["position"]


func _process(delta: float) -> bool:
	_time += delta
	if _time > MATCH_SECONDS + 25.0:
		return _fail("tempo esgotado (GO=%d, fim=%d)" % [_started, _ended])
	if _started == 0:
		return false

	for id in _spawn:
		var runner: Node3D = _match.get_node("Main/Runner" if id == 1 else "Main/Runner%d" % id)
		_farthest[id] = maxf(_farthest.get(id, 0.0), runner.global_position.distance_to(_spawn[id]))

	if _ended == 0:
		return false

	# Fim de partida: todos devem parar (o corredor desliga no match_ended)
	_after_end += delta
	if _frozen_at.is_empty():
		for id in _spawn:
			_frozen_at[id] = (_match.get_node("Main/Runner" if id == 1 else "Main/Runner%d" % id) as Node3D).global_position
	if _after_end < 0.5:
		return false

	return _verify()


func _verify() -> bool:
	var planet: Node = root.get_node("Services").planet
	var ids: Array = _spawn.keys()
	print("GO=%d fim=%d civilizações=%s" % [_started, _ended, ids])
	if _started != 1 or _ended != 1:
		return _fail("GO! e fim deveriam sair exatamente uma vez")
	if ids.size() != 4:
		return _fail("esperava 4 bases pousadas, vieram %d" % ids.size())
	for i in ids.size():
		var up: Vector3 = ((_spawn[ids[i]] as Vector3) - planet.center).normalized()
		if absf(absf(up.y) - 0.577) > 0.03:
			return _fail("civilização %d fora da faixa dos polos: |y|=%.3f" % [ids[i], absf(up.y)])
		for j in range(i + 1, ids.size()):
			var other: Vector3 = ((_spawn[ids[j]] as Vector3) - planet.center).normalized()
			var angle := rad_to_deg(up.angle_to(other))
			if angle < 85.0:
				return _fail("bases %d e %d a apenas %.0f° uma da outra" % [ids[i], ids[j], angle])
	var moving := 0
	for id in _farthest:
		print("  civilização %d percorreu até %.0f u do spawn" % [id, _farthest[id]])
		if id != 1 and _farthest[id] > 15.0:
			moving += 1
	if moving < 3:
		return _fail("os 3 bots deveriam ter saído a campo (saíram %d)" % moving)
	if _clock.is_empty() or _clock[0] != int(MATCH_SECONDS) or _clock[-1] != 0 or _clock.size() < int(MATCH_SECONDS):
		return _fail("relógio inesperado: %s" % [_clock])
	for id in _spawn:
		var runner: Node3D = _match.get_node("Main/Runner" if id == 1 else "Main/Runner%d" % id)
		if runner.global_position.distance_to(_frozen_at[id]) > 0.05:
			return _fail("corredor %d continuou correndo depois do fim" % id)
	print("OK")
	quit(0)
	return true
