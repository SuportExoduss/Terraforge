extends SceneTree
## Fotografa a PRIMEIRA CONQUISTA (DD-013; exige janela, sem --headless): anel de luz + faíscas no centro da área.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_burst.gd -- <pasta de saída>

var _match: Node
var _t := -1.0
var _shot := 0
var _fired := false
const SHOT_AT := [0.15, 0.5, 1.0]


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	root.add_child(_match)
	root.get_node("EventBus").match_started.connect(func() -> void: _t = 0.0)


func _process(delta: float) -> bool:
	if _t < 0.0:
		return false
	if not _fired and _t >= 1.8:   # depois do "GO!"; câmera normal do jogo, efeito sob o corredor
		_fired = true
		_t = 0.0
		var planet = root.get_node("Services").planet
		var runner: Node3D = _match.get_node("Main/Runner")
		var up: Vector3 = (runner.global_position - planet.center).normalized()
		var right := up.cross(Vector3.UP).normalized()
		var fwd := right.cross(up)
		var cells := PackedVector3Array()
		for i in 30:
			var p: Vector3 = up * 100.0 + (right * (i % 6 - 3) + fwd * (i / 6 - 3)) * 1.5
			cells.append(planet.center + p.normalized() * 100.0)
		var bus: Node = root.get_node("EventBus")
		bus.territory_cells_claimed.emit(1, cells, 1.5)
		bus.territory_loop_claimed.emit(1, cells.size())
	if not _fired:
		_t += delta
		return false
	_t += delta
	if _shot < SHOT_AT.size() and _t >= SHOT_AT[_shot]:
		var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
		root.get_texture().get_image().save_png("%s/burst_%d.png" % [out, _shot])
		_shot += 1
	if _shot >= SHOT_AT.size():
		quit(0)
	return false
