extends SceneTree
## Fotografa o menu com o dock e as telas dele (Civilizações, Perfil, Loja) — exige janela, sem --headless.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_screens.gd -- <pasta de saída>

var _out := ""
var _frame := 0
var _menu: Node
var _names := ["Civilizations", "Profile", "Shop"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(_menu)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 30:
		root.get_texture().get_image().save_png("%s/screens_menu.png" % _out)
	var step := (_frame - 30) / 10
	if _frame > 30 and (_frame - 30) % 10 == 1 and step < _names.size():
		var button: Node = _menu.get_node_or_null("Box/Dock/" + _names[step])
		if button != null:
			button.pressed.emit()
	if _frame > 30 and (_frame - 30) % 10 == 9 and step < _names.size():
		root.get_texture().get_image().save_png("%s/screens_%s.png" % [_out, _names[step]])
		var screen: Node = _menu.get_node_or_null("Screen")
		if screen != null:
			screen.back.pressed.emit()
	if _frame > 70:
		quit(0)
	return false
