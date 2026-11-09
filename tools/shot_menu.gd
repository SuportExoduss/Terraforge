extends SceneTree
## Fotografa a abertura viva do menu (exige janela, sem --headless): uma foto normal, uma com aurora e meteoro.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_menu.gd -- <pasta de saída>

var _out := ""
var _frame := 0
var _menu: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(_menu)


func _process(_delta: float) -> bool:
	_frame += 1
	var back: Node = _menu.get_node("Backdrop")
	if _frame == 30:
		root.get_texture().get_image().save_png("%s/menu_00.png" % _out)
	if _frame == 31:
		back.show_aurora()
		back._aurora_age = back.AURORA_SECONDS * 0.5
		back.spawn_meteor()
	if _frame == 40:
		root.get_texture().get_image().save_png("%s/menu_01.png" % _out)
		quit(0)
	return false
