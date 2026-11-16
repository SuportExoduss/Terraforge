class_name PausePanel
extends CanvasLayer
## Passo 127 (DD-167): PAUSA da partida. O botão "II" do HUD, o ESC e o botão voltar do Android (back()) abrem este painel;
## a partida solo congela de verdade (get_tree().paused) e volta do ponto exato. CONTINUAR, CONFIGURAÇÕES (o mesmo
## painel do menu, com o VOLTAR dele) e SAIR DA PARTIDA (pede confirmação; sair NÃO dá XP, moedas nem conta partida).
## Só abre antes do fim do tempo: do TIME_UP em diante quem manda é o pós-jogo (replay / resultados).
## ponytail: sem pausa de rede — a partida online é do servidor e não passa por aqui.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const BUTTON_SIZE := Vector2(300.0, 52.0)   # ≥ 44 px de altura: dedo no celular deitado

var is_open := false

var _paused_at := 0
var _main: VBoxContainer
var _confirm: VBoxContainer
var _root: Control
var _settings: SettingsPanel


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS   # com a árvore pausada, só este painel continua vivo
	visible = false
	EventBus.match_pause_requested.connect(back)

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.build()   # filho de CanvasLayer não herda o tema da janela
	add_child(_root)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.02, 0.03, 0.08, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)   # engole o toque: nada passa para o jogo por trás
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)

	_main = _column(box, "Main")
	_button(_main, "Resume", "CONTINUAR", close)
	_button(_main, "Settings", "CONFIGURAÇÕES", _open_settings)
	_button(_main, "Quit", "SAIR DA PARTIDA", _show.bind(true))

	_confirm = _column(box, "Confirm")
	var ask := Label.new()
	ask.name = "Ask"
	ask.text = "Sair agora?\nA partida não vale XP nem moedas."
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(ask)
	_button(_confirm, "Back", "VOLTAR", _show.bind(false))
	_button(_confirm, "Leave", "SAIR E PERDER A PARTIDA", _leave)
	_confirm.visible = false


func _exit_tree() -> void:
	if is_open and get_tree() != null:
		get_tree().paused = false   # a cena foi trocada/recarregada com a pausa aberta: nunca deixa a árvore parada


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # ESC (e B do controle)
		get_viewport().set_input_as_handled()
		back()


## Voltar (ESC / botão do Android / "II" do HUD): sem pausa abre; com pausa fecha a camada mais interna.
func back() -> void:
	if not is_open:
		open()
	elif _settings != null:
		_settings.close()
	elif _confirm.visible:
		_show(false)
	else:
		close()


func can_open() -> bool:
	return Services.flow == null or Services.flow.state < MatchFlow.State.TIME_UP


func open() -> void:
	if is_open or not can_open():
		return
	is_open = true
	_paused_at = Time.get_ticks_msec()
	TouchSteering.set_ui_pointer_held(false)
	TouchSteering.clear()   # solta o analógico: voltar da pausa não pode continuar virando
	_show(false)
	visible = true
	get_tree().paused = true
	EventBus.match_pause_changed.emit(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	EventBus.match_pause_changed.emit(false)


## Quanto tempo (ms de parede) a pausa atual já dura — o HUD empurra os relógios dos bônus por isso ao voltar.
func paused_msec() -> int:
	return Time.get_ticks_msec() - _paused_at if is_open else 0


func _show(confirm: bool) -> void:
	_main.visible = not confirm
	_confirm.visible = confirm
	var focus: Button = _confirm.get_node("Back") if confirm else _main.get_node("Resume")   # o seguro é o padrão
	focus.grab_focus()


func _open_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.name = "SettingsPanel"
	_settings.closed.connect(func() -> void:
		_settings.queue_free()
		_settings = null
		_main.get_node("Settings").grab_focus())
	_root.add_child(_settings)


func _leave() -> void:
	is_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MainMenu.MENU_SCENE)   # sem Services.flow.go(MENU): isso passaria pela apuração e pagaria a partida


func _column(parent: Control, column_name: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = column_name
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)
	return column


func _button(parent: Control, button_name: String, label: String, action: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	parent.add_child(button)
