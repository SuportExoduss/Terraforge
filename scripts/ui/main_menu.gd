class_name MainMenu
extends Control
## Menu inicial (cap. 04: Menu → partida → Resultados → Menu): título, perfil salvo (nível, XP, moedas), JOGAR, CONFIGURAÇÕES (UI-006) e SAIR.
## ponytail: sem lobby nem matchmaking — a partida usa os padrões do MatchSetup (3 adversários); entram com o multiplayer.

const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()   # `--server` vale antes ou depois do `--`
	if DedicatedServer.requested(args):   # servidor dedicado (DD-134): sem menu, o processo vira a sala
		var server := DedicatedServer.new()
		server.configure(args)
		get_tree().root.add_child.call_deferred(server)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.05, 0.12)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "TERRAFORGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)

	Profile.load_data()
	Settings.apply_all()   # volumes e qualidade salvos valem desde o menu
	var profile := Label.new()
	profile.name = "Profile"
	profile.text = "Nível %d  ·  %d XP  ·  %d moedas  ·  %d partidas  ·  conquistas %d/%d" % [Profile.level(), Profile.data["xp"], Profile.data["coins"], Profile.data["matches"], Profile.data["achievements"].size(), Achievements.LIST.size()]
	profile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile.add_theme_font_size_override("font_size", 20)
	box.add_child(profile)

	var play := _add_button(box, "Play", "JOGAR", func(): get_tree().change_scene_to_file(MATCH_SCENE))
	_add_button(box, "Settings", "CONFIGURAÇÕES", _open_settings)
	_add_button(box, "Quit", "SAIR", func(): get_tree().quit())
	play.grab_focus()   # teclado / controle


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	panel.name = "SettingsPanel"
	panel.closed.connect(func():
		panel.queue_free()
		get_node("Box/Settings").grab_focus())
	add_child(panel)


func _add_button(parent: Control, button_name: String, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.custom_minimum_size = Vector2(240.0, 56.0)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
