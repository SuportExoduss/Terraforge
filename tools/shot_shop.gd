extends SceneTree
## Fotografa a loja com saldo para comprar vários itens e UM COMPRAR sob o mouse (perfil de teste; exige janela).
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_shop.gd -- <pasta de saída>

var _out := ""
var _frame := 0
var _menu: Node


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	await process_frame
	var profile = load("res://scripts/core/profile.gd")
	profile.path = "user://profile_shot_shop.json"
	DirAccess.remove_absolute("user://profile_shot_shop.json")
	profile.load_data()
	profile.data["matches"] = 5
	profile.data["coins"] = 5000
	profile.save()   # o menu recarrega o perfil do arquivo
	_menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(_menu)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 20:
		_menu.get_node("Box/Dock/Shop").pressed.emit()
	if _frame == 40:
		var shop: Node = _menu.get_node("Screen")
		var rows := shop.find_children("Item_*", "Button", true, false)
		for button: Button in rows:
			if button.text.begins_with("COMPRAR") and not button.disabled:
				button.mouse_entered.emit()   # o 1º COMPRAR possível vira o alvo
				break
	if _frame == 50:
		root.get_texture().get_image().save_png("%s/loja.png" % _out)
		DirAccess.remove_absolute("user://profile_shot_shop.json")
		quit(0)
	return false
