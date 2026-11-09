extends SceneTree
## Fotografa o mergulho do menu no planeta (exige janela, sem --headless): 3 fotos durante a descida.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_dive.gd -- <pasta de saída>

var _out := ""
var _frame := 0
var _clock := -1.0
var _shots := 0
var _menu: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(_menu)


func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 20:
		_menu.get_node("Box/Play").pressed.emit()
		_clock = 0.0
	if _clock >= 0.0 and is_instance_valid(_menu):
		_clock += delta
		if _shots < 3 and _clock >= [0.8, 1.35, 1.7][_shots]:
			root.get_texture().get_image().save_png("%s/dive_%d.png" % [_out, _shots])
			_shots += 1
	if _shots >= 3:
		quit(0)
	return false
