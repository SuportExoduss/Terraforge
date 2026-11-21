class_name MenuScreen
extends Control
## Base das telas do menu (Civilizações, Perfil, Loja): fundo escuro, título, um corpo para o conteúdo e VOLTAR.
## `closed` avisa o dono (o menu) para tirar a tela; Esc também volta. As telas filhas montam o corpo em `build`.
## Uma coluna só, centralizada; se a janela for menor que o conteúdo, a tela rola (`scrolling_center`).

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const SafeArea := preload("res://scripts/core/safe_area.gd")
const BACK_SIZE := Vector2(240.0, 52.0)   # Passo 129: VOLTAR preso na base da tela, com altura de dedo
const BACK_GAP := 10.0

signal closed

var title_text := ""
var body: VBoxContainer
var back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.backdrop())   # Passo 109: fundo em gradiente + conteúdo num cartão de vidro (o tema vem do Services)
	var center := scrolling_center(self)
	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(660.0, 0.0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	box.add_child(body)
	build(body)
	back = pinned_back(self, close)
	focus_start()


## Passo 158 (DD-197): o teclado já começa dentro da tela, no primeiro controle habilitado do corpo (as setas e o ENTER agem de
## imediato); sem nenhum (tela só de leitura), no VOLTAR.
func focus_start() -> void:
	var first := first_focusable(body)
	(first if first != null else back).grab_focus()


## Primeiro botão, controle deslizante ou campo habilitado e visível sob `root` (na ordem da tela); `null` se não houver.
static func first_focusable(root: Node) -> Control:
	for found in root.find_children("*", "Control", true, false):
		var c := found as Control
		if c.focus_mode == Control.FOCUS_NONE or not c.is_visible_in_tree():
			continue
		if c is BaseButton and (c as BaseButton).disabled:
			continue
		if c is BaseButton or c is Slider or c is LineEdit:
			return c
	return null


## Passo 158: setas, TAB ou ENTER — as teclas que só fazem sentido com algum controle focado.
static func is_nav(event: InputEvent) -> bool:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev", "ui_accept"]:
		if event.is_action_pressed(action):
			return true
	return false


## Área que ocupa a tela toda, centraliza o que recebe e ganha barra de rolagem vertical quando o conteúdo não cabe
## (janela pequena). Devolve o container onde o conteúdo entra. Também usada pelo SettingsPanel.
static func scrolling_center(parent: Control) -> CenterContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := SafeArea.insets(parent)   # Passo 129: a rolagem fica dentro da área segura e termina acima do VOLTAR preso
	scroll.offset_left = inset.x
	scroll.offset_top = inset.y
	scroll.offset_right = -inset.z
	scroll.offset_bottom = -(inset.w + BACK_SIZE.y + 2.0 * BACK_GAP)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true   # Tab/setas levam o botão focado para dentro da vista
	parent.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # cabendo, ocupa a tela toda e centraliza
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	return center


## Passo 129: o VOLTAR fica preso na base da tela (a rolagem acaba acima dele): nunca some quando o conteúdo é mais alto
## que a tela e respeita a barra de gestos do celular. Também usado pelo SettingsPanel.
static func pinned_back(parent: Control, action: Callable) -> Button:
	var inset := SafeArea.insets(parent)
	var button := Button.new()
	button.name = "Back"
	button.text = "VOLTAR"
	button.custom_minimum_size = BACK_SIZE
	button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button.offset_left = -BACK_SIZE.x * 0.5
	button.offset_right = BACK_SIZE.x * 0.5
	button.offset_top = -inset.w - BACK_GAP - BACK_SIZE.y
	button.offset_bottom = -inset.w - BACK_GAP
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


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
	elif is_nav(event) and get_viewport().gui_get_focus_owner() == null:   # foco perdido (o botão focado sumiu): a próxima seta o devolve
		accept_event()
		focus_start()


func make_label(text: String, size := 20, node_name := "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if node_name != "":
		label.name = node_name
	return label
