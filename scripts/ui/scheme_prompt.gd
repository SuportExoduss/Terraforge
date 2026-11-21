class_name SchemePrompt
extends Control
## Passo 157 (DD-196): a primeira vez no PC o jogo pergunta com que teclas o personagem gira — A / D ou ← / →. O outro par fica para o
## mapa (tecla M). Tudo por teclado: ← → trocam de opção, ENTER escolhe. ESC fecha sem escolher (pergunta de novo na próxima vez).
## Dá para mudar depois em CONFIGURAÇÕES › Controles.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

signal chosen(scheme: int)   # 1 = A / D, 2 = setas

var _done := false


func _ready() -> void:
	name = "SchemePrompt"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # o menu atrás não recebe clique enquanto a pergunta está aberta
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520.0, 0.0)
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := Label.new()
	title.text = "COMO QUER JOGAR?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Escolha as teclas que giram o seu personagem.\nO outro grupo de teclas controla o mapa (tecla M)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var wasd := _option(row, "Wasd", "A  /  D", 1)
	_option(row, "Arrows", "←  /  →", 2)
	var foot := Label.new()
	foot.text = "← → escolhem  ·  ENTER confirma  ·  dá para mudar em CONFIGURAÇÕES"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", UiTheme.INK_DIM)
	box.add_child(foot)
	wasd.grab_focus()


func _option(parent: Control, node_name: String, label: String, scheme: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 30)
	button.pressed.connect(_choose.bind(scheme))
	parent.add_child(button)
	return button


func _choose(scheme: int) -> void:
	if _done:
		return
	_done = true
	Settings.set_scheme(scheme)
	chosen.emit(scheme)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_done = true
		queue_free()
