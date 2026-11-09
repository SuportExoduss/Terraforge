class_name MenuScreen
extends Control
## Base das telas do menu (Civilizações, Perfil, Loja): fundo escuro, título, um corpo para o conteúdo e VOLTAR.
## `closed` avisa o dono (o menu) para tirar a tela; Esc também volta. As telas filhas montam o corpo em `build`.
## ponytail: uma coluna só, sem rolagem — o conteúdo de cada tela cabe nos 540 px da janela.

signal closed

var title_text := ""
var body: VBoxContainer
var back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.05, 0.12)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(620.0, 0.0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	box.add_child(body)
	build(body)
	back = Button.new()
	back.name = "Back"
	back.text = "VOLTAR"
	back.custom_minimum_size = Vector2(240.0, 48.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	box.add_child(back)
	back.grab_focus()


## Cada tela monta o seu conteúdo aqui.
func build(_parent: VBoxContainer) -> void:
	pass


func close() -> void:
	Profile.save()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()


func make_label(text: String, size := 20, node_name := "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if node_name != "":
		label.name = node_name
	return label
