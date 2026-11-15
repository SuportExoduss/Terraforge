extends SceneTree
## Fotografa a tela de Configurações aberta pelo menu — exige janela, sem --headless.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_settings.gd -- <pasta de saída>

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
	if _frame == 20:
		_menu.find_child("Settings", true, false).pressed.emit()
	if _frame == 40:
		print("foto erro=", root.get_texture().get_image().save_png("%s/configuracoes.png" % _out))
		quit(0)
	return false
