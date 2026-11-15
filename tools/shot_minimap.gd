extends SceneTree
## Fotografa o minimapa aberto e a câmera de contemplação (fim de partida). Exige janela.
## Uso: godot_console --path . -s res://tools/shot_minimap.gd -- <pasta de saída>

var _match: Node
var _out := ""


func _initialize() -> void:
	load("res://scripts/core/profile.gd").path = "user://profile_shot.json"   # nunca grava no perfil de verdade
	_out = OS.get_cmdline_user_args()[0]
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	root.add_child(_match)
	_run()


func _snap(name: String) -> void:
	await create_timer(0.4).timeout   # a imagem lida é a do quadro anterior
	print("foto ", name, " erro=", root.get_texture().get_image().save_png("%s/%s.png" % [_out, name]))


func _run() -> void:
	await root.get_node("EventBus").match_started
	await create_timer(4.0).timeout
	var mm: Control = _match.get_node("Hud/Minimap")
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		mm._gui_input(e)
	await _snap("minimapa_aberto")
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		mm._gui_input(e)
	root.get_node("EventBus").match_ended.emit()
	await create_timer(6.0).timeout
	await _snap("contemplacao")
	quit(0)
