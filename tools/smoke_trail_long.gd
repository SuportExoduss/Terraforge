extends SceneTree
## Teste de fumaça: rastro MUITO longo (bug: a cerca parava de aparecer ao esgotar o bolso de 64 postes).
## Grava 200 pontos (3x o estoque inicial) e confere: um poste visível por ponto, um elo por par, todos no lugar;
## limpar devolve tudo ao bolso; um 2º rastro longo reaproveita o bolso (não cresce de novo).
## Uso: godot_console --headless --path . -s res://tools/smoke_trail_long.gd

var _trail: Node
var _planet: Node3D
var _time := 0.0
var _started := false


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	_trail = root.get_node("Main/Runner/Trail")
	_planet = root.get_node("Main/Planet")


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	quit(1)


func _visible(list: Array) -> int:
	return list.filter(func(n: Node3D) -> bool: return n.visible).size()


# `count` pontos ao longo de um círculo máximo (espaçados ~2 u, acima do mínimo de 1,5), com um offset de fase.
func _record(count: int, phase: float) -> Vector3:
	var radius: float = _planet.get_surface_radius(Vector3.UP) + 0.15
	var last := Vector3.ZERO
	for i in count:
		var angle := phase + i * (2.0 / radius)
		last = _planet.center + Vector3(sin(angle), cos(angle), 0.0) * radius
		_trail._record_point_if_far_enough(last)
	return last


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		_fail("tempo esgotado")
		return true
	if _started or not _planet.surface_ready:
		return false
	_started = true
	_trail.set_process(false)   # só os pontos injetados valem

	var prewarm: int = _trail.prewarm_segments
	if _trail._posts.size() != prewarm:
		_fail("bolso inicial %d != prewarm %d" % [_trail._posts.size(), prewarm])
		return true

	var count := prewarm * 3 + 8
	var last := _record(count, 0.0)
	var posts := _visible(_trail._posts)
	var links := _visible(_trail._links)
	print("rastro longo: pontos=%d postes=%d elos=%d bolso=%d" % [_trail.points.size(), posts, links, _trail._posts.size()])
	if _trail.points.size() != count or posts != count or links != count - 1:
		_fail("a cerca parou de aparecer: pontos=%d postes=%d elos=%d" % [_trail.points.size(), posts, links])
		return true

	# o último poste está de fato no último ponto (e não na origem, escondido num bolso novo mal posicionado)
	var tail: Node3D = _trail._posts[count - 1]
	if tail.global_position.distance_to(last) > 0.01:
		_fail("último poste fora do lugar: %s vs %s" % [tail.global_position, last])
		return true
	# o último elo liga o penúltimo ao último poste (ponto médio entre eles, a ~altura do elo)
	var mid: Vector3 = (_trail.points[count - 2] + _trail.points[count - 1]) * 0.5
	if (_trail._links[count - 2] as Node3D).global_position.distance_to(mid) > 0.5:
		_fail("último elo fora do lugar")
		return true

	# limpar: tudo some e volta ao bolso; novo rastro longo não faz o bolso crescer
	var grown: int = _trail._posts.size()
	_trail._clear()
	if _visible(_trail._posts) != 0 or _visible(_trail._links) != 0 or not _trail.points.is_empty():
		_fail("limpar não escondeu a cerca")
		return true
	_record(count, 1.0)
	if _trail._posts.size() != grown or _visible(_trail._posts) != count or _visible(_trail._links) != count - 1:
		_fail("2º rastro não reaproveitou o bolso (bolso %d -> %d)" % [grown, _trail._posts.size()])
		return true
	print("OK")
	quit(0)
	return true
