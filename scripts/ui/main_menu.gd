class_name MainMenu
extends Control
## Menu inicial (cap. 04: Menu → partida → Resultados → Menu): título, perfil salvo (nível, XP, moedas), JOGAR e SAIR.
## ponytail: sem lobby, matchmaking nem opções — a partida usa os padrões do MatchSetup (3 adversários); entram com o multiplayer.

const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.05, 0.12)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_CENTER)
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
	var profile := Label.new()
	profile.name = "Profile"
	profile.text = "Nível %d  ·  %d XP  ·  %d moedas  ·  %d partidas" % [Profile.level(), Profile.data["xp"], Profile.data["coins"], Profile.data["matches"]]
	profile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile.add_theme_font_size_override("font_size", 20)
	box.add_child(profile)

	var play := _add_button(box, "Play", "JOGAR", func(): get_tree().change_scene_to_file(MATCH_SCENE))
	_add_button(box, "Quit", "SAIR", func(): get_tree().quit())
	play.grab_focus()   # teclado / controle


func _add_button(parent: Control, button_name: String, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.custom_minimum_size = Vector2(240.0, 56.0)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
