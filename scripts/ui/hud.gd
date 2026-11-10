class_name Hud
extends CanvasLayer
## HUD da partida: relógio, domínio, vida em corações (DD-105), contagem de respawn, aviso de evento e o
## analógico flutuante. Montado em código e dirigido só pelo EventBus (a UI não conhece o Gameplay);
## mostra apenas o jogador local — o placar dos adversários é da tela de resultados (6f).
## ponytail: fonte padrão do Godot e quadrados no lugar de ícones de coração; arte final na fase de polimento.

const HEARTS := 5   # 4 normais + 1 do bônus Vida Extra (SYS-005), escondido até existir
const BASE_POINTS := 16
const BONUS_FLASH_SECONDS := 1.5
const SEGMENTS_PER_HEART := 4
const FULL := Color(1.0, 0.27, 0.32)
const EMPTY := Color(0.12, 0.12, 0.15, 0.85)
const AMBER := Color(1.0, 0.85, 0.3)
const QUADRANT := 10.0
const GAP := 1.0
const HEART_GAP := 8.0
const GO_SECONDS := 1.0
const IMPACT_SECONDS := 1.2
const JOYSTICK_RADIUS := 60.0   # = PlayerSteering.joystick_radius_pixels
const KNOB_RADIUS := 22.0

var _clock: Label
var _score: Label
var _countdown: Label
var _event: Label
var _hearts: Control
var _joystick: Control
var _bonus_column: VBoxContainer
var _stock_button: Button            # Passo 60: próximo bônus guardado; toque ou ESPAÇO usa
var _bonus_labels: Dictionary = {}   # nome do bônus -> Label
var _bonus_until: Dictionary = {}    # nome -> {until_ms, timed}


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # o HUD nunca engole o toque de direção
	add_child(root)

	_clock = _label(root, "ClockLabel", 30, Color.WHITE, Control.PRESET_TOP_WIDE, Vector2(0, 14))
	_score = _label(root, "ScoreLabel", 18, Color.WHITE, Control.PRESET_TOP_LEFT, Vector2(16, 18))
	_event = _label(root, "EventLabel", 26, AMBER, Control.PRESET_TOP_WIDE, Vector2(0, 62))
	_countdown = _label(root, "CountdownLabel", 110, Color.WHITE, Control.PRESET_FULL_RECT, Vector2.ZERO)
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score.text = "Domínio: 0,0%"

	_build_hearts(root)
	_build_bonus_column(root)
	_joystick = Control.new()
	_joystick.name = "Joystick"
	_joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick.visible = false
	_joystick.draw.connect(_draw_joystick)
	root.add_child(_joystick)

	EventBus.match_clock_changed.connect(_on_clock)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.territory_score_changed.connect(_on_score)
	EventBus.health_changed.connect(_on_health)
	EventBus.respawn_countdown.connect(_on_respawn_countdown)
	EventBus.global_event_warning.connect(_on_event_warning)
	EventBus.bonus_activated.connect(_on_bonus)
	EventBus.bonus_stock_changed.connect(_on_stock)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		EventBus.bonus_use_requested.emit(Civilization.PLAYER_ID)
		get_viewport().set_input_as_handled()


func _on_match_ended() -> void:
	_clock.text = ""   # o painel de resultados assume a tela
	_stock_button.hide()


func _process(_delta: float) -> void:
	_joystick.visible = TouchSteering.is_active
	if _joystick.visible:
		_joystick.queue_redraw()
	_tick_bonuses()


func _label(parent: Control, label_name: String, size: int, color: Color, preset: int, offset: Vector2) -> Label:
	var l := Label.new()
	l.name = label_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.13))
	l.add_theme_constant_override("outline_size", maxi(3, size / 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(preset)
	l.position += offset
	if preset == Control.PRESET_TOP_LEFT:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(l)
	return l


# 4 quadrados (corações) lado a lado, cada um em 4 quadrantes 2x2: o quadrante APAGA ao perder o ponto.
func _build_hearts(parent: Control) -> void:
	_hearts = Control.new()
	_hearts.name = "Hearts"
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heart_width := QUADRANT * 2.0 + GAP
	parent.add_child(_hearts)
	_hearts.offset_left = 16.0   # canto superior esquerdo, sob o domínio (o canto direito é do minimapa, DD-104)
	_hearts.offset_top = 48.0
	for heart in HEARTS:
		for quadrant in SEGMENTS_PER_HEART:
			var segment := ColorRect.new()
			segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			segment.size = Vector2.ONE * QUADRANT
			segment.position = Vector2(
					heart * (heart_width + HEART_GAP) + (quadrant % 2) * (QUADRANT + GAP),
					(quadrant / 2) * (QUADRANT + GAP))
			_hearts.add_child(segment)
	_refresh_hearts(BASE_POINTS, BASE_POINTS)


func _refresh_hearts(points: int, max_points: int) -> void:
	for i in _hearts.get_child_count():
		var segment := _hearts.get_child(i) as ColorRect
		segment.visible = i < max_points
		segment.color = FULL if i < points else EMPTY


# SYS-005: coluna de bônus na lateral direita. Efeito com duração mostra a contagem; instantâneo pisca e some.
func _build_bonus_column(parent: Control) -> void:
	_bonus_column = VBoxContainer.new()
	_bonus_column.name = "Bonuses"
	_bonus_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_bonus_column)
	_bonus_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_bonus_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bonus_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bonus_column.offset_left = -16.0
	_bonus_column.offset_right = -16.0
	_stock_button = Button.new()
	_stock_button.name = "Stock"
	_stock_button.focus_mode = Control.FOCUS_NONE   # senão o ESPAÇO acionaria o botão por foco E pelo atalho
	_stock_button.add_theme_font_size_override("font_size", 20)
	_stock_button.visible = false
	_stock_button.button_down.connect(TouchSteering.set_ui_pointer_held.bind(true))   # o toque no botão não vira direção
	_stock_button.button_up.connect(TouchSteering.set_ui_pointer_held.bind(false))
	_stock_button.pressed.connect(func(): EventBus.bonus_use_requested.emit(Civilization.PLAYER_ID))
	_bonus_column.add_child(_stock_button)


# Estoque do jogador: mostra o próximo a ser usado e quantos há guardados.
func _on_stock(owner_id: int, kinds: Array) -> void:
	if owner_id != Civilization.PLAYER_ID:
		return
	_stock_button.visible = not kinds.is_empty()
	if not kinds.is_empty():
		_stock_button.text = "ESPAÇO · %s  [%d]" % [kinds[0], kinds.size()]


func _on_bonus(owner_id: int, kind: String, seconds: float) -> void:
	if owner_id != Civilization.PLAYER_ID:
		return
	if not _bonus_labels.has(kind):
		_bonus_labels[kind] = _label(_bonus_column, "Bonus", 20, AMBER, Control.PRESET_TOP_LEFT, Vector2.ZERO)
	var label: Label = _bonus_labels[kind]
	label.text = kind
	label.visible = true
	_bonus_until[kind] = {"until_ms": Time.get_ticks_msec() + int((seconds if seconds > 0.0 else BONUS_FLASH_SECONDS) * 1000.0), "timed": seconds > 0.0}


func _tick_bonuses() -> void:
	for kind in _bonus_until.keys():
		var entry: Dictionary = _bonus_until[kind]
		var left_ms: int = entry["until_ms"] - Time.get_ticks_msec()
		var label: Label = _bonus_labels[kind]
		if left_ms <= 0:
			label.visible = false
			_bonus_until.erase(kind)
		elif entry["timed"]:
			label.text = "%s %ds" % [kind, ceili(left_ms / 1000.0)]


func _draw_joystick() -> void:
	_joystick.draw_arc(TouchSteering.origin, JOYSTICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
	_joystick.draw_circle(TouchSteering.origin + TouchSteering.knob_offset, KNOB_RADIUS, Color(1, 1, 1, 0.6))


func _on_clock(seconds_remaining: int) -> void:
	_clock.text = "%d:%02d" % [floori(seconds_remaining / 60.0), seconds_remaining % 60]


func _on_score(owner_id: int, owned_fraction: float) -> void:
	if owner_id == Civilization.PLAYER_ID:
		_score.text = "Domínio: %s%%" % ("%.1f" % (owned_fraction * 100.0)).replace(".", ",")


func _on_health(owner_id: int, points: int, max_points: int) -> void:
	if owner_id == Civilization.PLAYER_ID:
		_refresh_hearts(points, max_points)


func _on_respawn_countdown(owner_id: int, seconds_remaining: int) -> void:
	if owner_id != Civilization.PLAYER_ID:
		return
	if seconds_remaining > 0:
		_countdown.text = str(seconds_remaining)
	else:
		_flash(_countdown, "GO!", GO_SECONDS)


func _on_event_warning(event_name: String, seconds_remaining: int) -> void:
	if seconds_remaining > 0:
		_event.text = "%s... %d" % [event_name, seconds_remaining]
	else:
		_flash(_event, "IMPACTO!", IMPACT_SECONDS)


# Mostra o texto e o apaga depois, a menos que algo novo já o tenha trocado.
func _flash(label: Label, text: String, seconds: float) -> void:
	label.text = text
	# O temporizador é filho do rótulo: se a partida for liberada antes de ele disparar, morre junto (sem callback pendurado).
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(func():
		if label.text == text:
			label.text = ""
		timer.queue_free())
	label.add_child(timer)
	timer.start(seconds)
