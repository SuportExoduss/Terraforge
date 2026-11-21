class_name SettingsPanel
extends Control
## Tela de configurações (UI-006): dois controles de volume e três níveis de qualidade. Tudo aplica na hora (Settings);
## salva ao soltar o controle e ao voltar. `closed` avisa o dono (o menu) para tirar a tela.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const KEY_TITLES := {"left": "GIRAR À ESQUERDA", "right": "GIRAR À DIREITA", "sprint": "SPRINT", "ability": "HABILIDADE ESPECIAL", "bonus": "USAR BÔNUS", "map": "ABRIR O MAPA"}   # Passos 156 e 157: nome de cada ação na tela de teclas
const PREVIEW_BASE := 76.0   # = Hud.SPRINT_SIZE

var _capturing := ""   # ação esperando a próxima tecla ("" = nenhuma)
var _key_buttons := {}
var _scheme_buttons := {}   # 1 = "A / D", 2 = "← / →" (Passo 157)
var _map_hint: Label
var _first: Control   # Passo 158: onde o teclado começa (EFEITOS)
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preload("res://scripts/ui/ui_theme.gd").backdrop())   # Passo 112 (DD-149): mesmo fundo e cartão de vidro das outras telas

	var center := MenuScreen.scrolling_center(self)
	var card := PanelContainer.new()
	card.name = "Card"
	center.add_child(card)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(420.0, 0.0)
	box.add_theme_constant_override("separation", 8)   # cabe nos 540 px do celular deitado
	card.add_child(box)

	var title := Label.new()
	title.text = "CONFIGURAÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)

	_add_slider(box, "Sfx", "EFEITOS", "sfx")
	_add_slider(box, "Music", "MÚSICA", "music")
	_add_slider(box, "Turn", "GIRO (50% A 150%)", "turn")
	_add_slider(box, "Text", "TEXTO DA HUD (100% A 150%)", "text")
	_add_controls(box)

	var quality_label := Label.new()
	quality_label.text = "QUALIDADE GRÁFICA"
	box.add_child(quality_label)
	var row := HBoxContainer.new()
	row.name = "Quality"
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var group := ButtonGroup.new()
	for level in Settings.QUALITY_NAMES.size():
		var button := Button.new()
		button.name = "Q%d" % level
		button.text = Settings.QUALITY_NAMES[level]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = level == int(Settings.get_value("quality"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.pressed.connect(func(): Settings.set_value("quality", level))
		row.add_child(button)

	var reduce := CheckButton.new()
	reduce.name = "ReduceMotion"
	reduce.text = "REDUZIR MOVIMENTO (sem meteoros, auroras e relâmpagos)"
	reduce.custom_minimum_size = Vector2(0.0, 48.0)   # Passo 129: altura de dedo
	reduce.button_pressed = Settings.reduced_motion()
	reduce.toggled.connect(func(on: bool): Settings.set_value("reduce_motion", 1.0 if on else 0.0))
	box.add_child(reduce)

	var haptics := CheckButton.new()   # Passo 133: vibração do celular
	haptics.name = "Haptics"
	haptics.text = "VIBRAÇÃO"
	haptics.custom_minimum_size = Vector2(0.0, 48.0)
	haptics.button_pressed = Settings.haptics_on()
	haptics.toggled.connect(func(on: bool): Settings.set_value("haptics", 1.0 if on else 0.0))
	box.add_child(haptics)

	var tips := CheckButton.new()   # Passo 131: quem já sabe jogar desliga as dicas das primeiras partidas
	tips.name = "Tips"
	tips.text = "DICAS NAS PRIMEIRAS PARTIDAS"
	tips.custom_minimum_size = Vector2(0.0, 48.0)
	tips.button_pressed = Settings.tips_on()
	tips.toggled.connect(func(on: bool): Settings.set_value("tips", 1.0 if on else 0.0))
	box.add_child(tips)

	_back = MenuScreen.pinned_back(self, close)   # Passo 129: preso na base da tela
	_first = MenuScreen.first_focusable(box)   # Passo 158: o teclado começa no primeiro controle, não no VOLTAR
	(_first if _first != null else _back).grab_focus()


func close() -> void:
	Profile.save()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:   # Passo 128: ESC / botão voltar do Android
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()
	elif MenuScreen.is_nav(event) and get_viewport().gui_get_focus_owner() == null:   # Passo 158: foco perdido: a próxima seta o devolve
		accept_event()
		(_first if _first != null else _back).grab_focus()


# Passo 156 (DD-195): tamanho dos botões de toque (com um botão de amostra que muda junto), teclas do PC (clique e aperte a nova) e "restaurar".
# Passo 157 (DD-196): no PC o primeiro bloco é "GIRAR COM": A / D ou setas, e o OUTRO par vira o do mapa; depois cada tecla pode ser trocada (PAUSE é sempre ESC).
func _add_controls(box: Control) -> void:
	var slider := _add_slider(box, "ButtonSize", "TAMANHO DOS BOTÕES (60% A 140%)", "btn_size")
	var holder := CenterContainer.new()
	holder.name = "Preview"
	holder.custom_minimum_size = Vector2(0.0, PREVIEW_BASE * 1.4)   # reserva a altura do maior tamanho: o controle não pula sob o dedo
	box.add_child(holder)
	var sample := ActionButton.new(UiTheme.INK, "SPRINT", "»", true)
	sample.name = "PreviewButton"
	sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sample.custom_minimum_size = Vector2.ONE * PREVIEW_BASE * Settings.button_scale()
	holder.add_child(sample)
	slider.value_changed.connect(func(_v: float): sample.custom_minimum_size = Vector2.ONE * PREVIEW_BASE * Settings.button_scale())
	if not OS.has_feature("mobile"):   # teclado só no PC
		var scheme_label := Label.new()
		scheme_label.text = "GIRAR O PERSONAGEM COM"
		box.add_child(scheme_label)
		var scheme_row := HBoxContainer.new()
		scheme_row.name = "Scheme"
		scheme_row.add_theme_constant_override("separation", 8)
		box.add_child(scheme_row)
		for scheme in [1, 2]:
			var pick := Button.new()
			pick.name = "Wasd" if scheme == 1 else "Arrows"
			pick.text = "A  /  D" if scheme == 1 else "←  /  →"
			pick.toggle_mode = true
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pick.custom_minimum_size = Vector2(0.0, 48.0)
			pick.pressed.connect(func():
				Settings.set_scheme(scheme)
				_refresh_keys())
			scheme_row.add_child(pick)
			_scheme_buttons[scheme] = pick
		_map_hint = Label.new()
		_map_hint.name = "MapHint"
		_map_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_map_hint.custom_minimum_size = Vector2(420.0, 0.0)
		_map_hint.add_theme_font_size_override("font_size", 14)
		_map_hint.add_theme_color_override("font_color", UiTheme.INK_DIM)
		box.add_child(_map_hint)
		var keys_label := Label.new()
		keys_label.text = "TECLAS (aperte ENTER e depois a nova tecla)"
		box.add_child(keys_label)
		for action: String in Settings.KEY_ACTIONS:
			var row := HBoxContainer.new()
			row.name = "Key_" + action
			var label := Label.new()
			label.text = KEY_TITLES[action]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var button := Button.new()
			button.name = "Pick"
			button.custom_minimum_size = Vector2(190.0, 48.0)
			button.pressed.connect(_start_capture.bind(action))
			row.add_child(button)
			_key_buttons[action] = button
			box.add_child(row)
	var reset := Button.new()
	reset.name = "ResetControls"
	reset.text = "RESTAURAR CONTROLES"
	reset.custom_minimum_size = Vector2(0.0, 48.0)
	reset.pressed.connect(func():
		Settings.reset_controls()
		slider.value = Settings.get_value("btn_size")
		_capturing = ""
		_refresh_keys())
	box.add_child(reset)
	_refresh_keys()


func _start_capture(action: String) -> void:
	_capturing = action
	_refresh_keys()


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = "APERTE UMA TECLA..." if action == _capturing else Settings.key_label(action)
	if _map_hint == null:
		return
	var left := Settings.key_for("left")
	var right := Settings.key_for("right")
	(_scheme_buttons[1] as Button).set_pressed_no_signal(left == KEY_A and right == KEY_D)
	(_scheme_buttons[2] as Button).set_pressed_no_signal(left == KEY_LEFT and right == KEY_RIGHT)
	_map_hint.text = "Com o mapa aberto (%s): %s giram o planeta, + e − dão zoom e ESC fecha o mapa. PAUSE: ESC." % [Settings.key_label("map"), Settings.map_pan_text()]


# Esperando uma tecla: ela vai para a ação (ESC cancela; as proibidas, como as setas e o ENTER, são ignoradas sem sair da espera).
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _capturing == "" or key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode == KEY_ESCAPE:
		_capturing = ""
	elif Settings.set_key(_capturing, key.keycode if key.keycode != KEY_NONE else key.physical_keycode):
		_capturing = ""
	_refresh_keys()


func _add_slider(parent: Control, node_name: String, label_text: String, key: String) -> HSlider:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get_value(key)
	slider.custom_minimum_size = Vector2(0.0, 32.0)
	slider.value_changed.connect(func(value: float): Settings.set_value(key, value, false))
	slider.drag_ended.connect(func(_changed: bool): Profile.save())
	parent.add_child(slider)
	return slider
