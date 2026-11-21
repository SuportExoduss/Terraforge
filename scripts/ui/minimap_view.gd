class_name MinimapView
extends TextureRect
## A janela do minimapa (DD-104): sem moldura, só o planeta flutuando no canto superior direito. UM TOQUE
## abre a visão grande no centro (75% de opacidade), onde ARRASTAR gira o planeta; outro toque devolve ao
## canto. O SubViewport e a MinimapCamera (Gameplay) são filhos montados em minimap.tscn; esta janela só
## mostra a textura e fala com o resto pelo EventBus.
## ponytail: o minimapa mostra a cena inteira (sem camada própria para ícones); ícones/filtros no polimento.

const SafeArea := preload("res://scripts/core/safe_area.gd")

const MINI_SIZE := 150.0
const EXPANDED_SIZE := 420.0
const MARGIN := 12.0
const EXPANDED_ALPHA := 0.75
const TAP_MAX_MSEC := 300
const ZOOM_STEP := 1.25   # por clique de roda
const PAN_PIXELS_PER_SECOND := 120.0   # Passo 157: as teclas movem o planeta como um arraste contínuo (0,4 grau por pixel = 48 graus por segundo)
const ZOOM_PER_SECOND := 1.8           # Passo 157: + e - aproximam/afastam

var _expanded := false
var _dragged := false
var _down_msec := 0
var _hint: Label   # Passo 157: no PC, a tecla do mapa e (aberto) as teclas de mover aparecem na base da janela


func _ready() -> void:
	texture = ($SubViewport as SubViewport).get_texture()
	_layout()
	get_viewport().size_changed.connect(_layout)   # Passo 129: a área segura muda quando a tela gira
	EventBus.match_ended.connect(hide)   # o painel de resultados assume a tela
	if Settings.is_pc():
		_hint = Label.new()
		_hint.name = "KeyHint"
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_hint.offset_top = -20.0
		_hint.add_theme_font_size_override("font_size", 13)
		_hint.add_theme_color_override("font_outline_color", Color.BLACK)
		_hint.add_theme_constant_override("outline_size", 5)
		add_child(_hint)
		_refresh_hint()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down_msec = Time.get_ticks_msec()
			_dragged = false
			TouchSteering.set_ui_pointer_held(true)
		else:
			TouchSteering.set_ui_pointer_held(false)
			if not _dragged and Time.get_ticks_msec() - _down_msec <= TAP_MAX_MSEC:
				_toggle()
	elif event is InputEventMouseButton and event.pressed and _expanded and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		EventBus.minimap_zoomed.emit(ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
	elif event is InputEventMagnifyGesture and _expanded:
		EventBus.minimap_zoomed.emit(event.factor)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_dragged = true
		if _expanded:
			EventBus.minimap_dragged.emit(event.relative)


## Passo 157: no PC o mapa abre e fecha com a tecla escolhida em Ajustes (padrão M) e a partida continua; a tecla só vale com o mapa na tela.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and is_visible_in_tree() and key.keycode == Settings.key_for("map"):
		get_viewport().set_input_as_handled()
		_toggle()


## Passo 157: ESC (e VOLTAR do Android) fecha o mapa aberto ANTES de a pausa ver o evento: o primeiro ESC guarda o mapa, o segundo pausa.
func _input(event: InputEvent) -> void:
	if _expanded and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_toggle()


## Passo 157: com o mapa aberto, o OUTRO par de teclas (Settings.map_pan_keys: W A S D ou as setas) gira o planeta e + / - dão zoom.
func _process(delta: float) -> void:
	if not _expanded or not is_visible_in_tree():
		return
	var keys := Settings.map_pan_keys()
	var pan := Vector2(float(Input.is_key_pressed(keys[1])) - float(Input.is_key_pressed(keys[0])), float(Input.is_key_pressed(keys[3])) - float(Input.is_key_pressed(keys[2])))
	if pan != Vector2.ZERO:   # a tecla leva a VISTA nessa direção: o planeta anda ao contrário (o contrário de arrastar com o dedo)
		EventBus.minimap_dragged.emit(-pan * PAN_PIXELS_PER_SECOND * delta)
	var zoom := float(Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS) or Input.is_key_pressed(KEY_KP_ADD)) - float(Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT))
	if zoom != 0.0:
		EventBus.minimap_zoomed.emit(pow(ZOOM_PER_SECOND, zoom * delta))


func _refresh_hint() -> void:
	if _hint != null:
		_hint.text = ("%s / ESC FECHA  ·  %s MOVE  ·  + − ZOOM" % [Settings.key_label("map"), Settings.map_pan_text()]) if _expanded else "%s  MAPA" % Settings.key_label("map")


func _toggle() -> void:
	_expanded = not _expanded
	_layout()
	_refresh_hint()
	EventBus.minimap_held.emit(_expanded)


func _layout() -> void:
	if _expanded:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -EXPANDED_SIZE * 0.5
		offset_right = EXPANDED_SIZE * 0.5
		offset_top = -EXPANDED_SIZE * 0.5
		offset_bottom = EXPANDED_SIZE * 0.5
	else:
		var inset := SafeArea.insets(self)   # Passo 129: fora do entalhe; o botão II do HUD acompanha pela raiz recuada
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -MINI_SIZE - MARGIN - inset.z
		offset_right = -MARGIN - inset.z
		offset_top = MARGIN + inset.y
		offset_bottom = MARGIN + inset.y + MINI_SIZE
	modulate.a = EXPANDED_ALPHA if _expanded else 1.0
