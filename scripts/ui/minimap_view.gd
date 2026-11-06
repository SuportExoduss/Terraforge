class_name MinimapView
extends TextureRect
## A janela do minimapa (DD-104): sem moldura, só o planeta flutuando no canto superior direito. UM TOQUE
## abre a visão grande no centro (75% de opacidade), onde ARRASTAR gira o planeta; outro toque devolve ao
## canto. O SubViewport e a MinimapCamera (Gameplay) são filhos montados em minimap.tscn; esta janela só
## mostra a textura e fala com o resto pelo EventBus.
## ponytail: o minimapa mostra a cena inteira (sem camada própria para ícones); ícones/filtros no polimento.

const MINI_SIZE := 150.0
const EXPANDED_SIZE := 420.0
const MARGIN := 12.0
const EXPANDED_ALPHA := 0.75
const TAP_MAX_MSEC := 300

var _expanded := false
var _dragged := false
var _down_msec := 0


func _ready() -> void:
	texture = ($SubViewport as SubViewport).get_texture()
	_layout()
	EventBus.match_ended.connect(hide)   # o painel de resultados assume a tela


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
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_dragged = true
		if _expanded:
			EventBus.minimap_dragged.emit(event.relative)


func _toggle() -> void:
	_expanded = not _expanded
	_layout()
	EventBus.minimap_held.emit(_expanded)


func _layout() -> void:
	if _expanded:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -EXPANDED_SIZE * 0.5
		offset_right = EXPANDED_SIZE * 0.5
		offset_top = -EXPANDED_SIZE * 0.5
		offset_bottom = EXPANDED_SIZE * 0.5
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -MINI_SIZE - MARGIN
		offset_right = -MARGIN
		offset_top = MARGIN
		offset_bottom = MARGIN + MINI_SIZE
	modulate.a = EXPANDED_ALPHA if _expanded else 1.0
