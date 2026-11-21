extends SceneTree
## Foto do foco do teclado (Passo 158) — exige janela. Abre o painel de Ajustes e põe o foco no controle de nome <foco>.
## Uso: godot_console --path . --resolution 900x760 -s res://tools/shot_keyboard_nav.gd -- <arquivo.png> <nome do controle>

var _time := 0.0
var _out := ""
var _focus := ""
var _panel: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_focus = args[1] if args.size() > 1 else "Sfx"
	var profile: Object = load("res://scripts/core/profile.gd")
	profile.path = "user://profile_shot_keyboard_nav.json"   # perfil descartável
	profile.data = profile.defaults()
	profile.save()
	_panel = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(_panel)


func _process(delta: float) -> bool:
	_time += delta
	if _time > 0.3 and _panel.find_child(_focus, true, false) != null and root.gui_get_focus_owner() != _panel.find_child(_focus, true, false):
		(_panel.find_child(_focus, true, false) as Control).grab_focus()
	if _time >= 1.5:
		print("foto erro=", root.get_texture().get_image().save_png(_out))
		quit(0)
		return true
	return false
