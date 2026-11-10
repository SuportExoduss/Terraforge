class_name MatchReplay
extends Node
## Replay cinematográfico (cap. 03, parte 11; DD-037: "o replay é parte da recompensa"). Guarda cada lote de células
## conquistadas com o relógio da partida e, no estado REPLAY (MatchFlow), repinta o planeta do zero em velocidade
## acelerada: a partida inteira cabe em replay_seconds. Ao sair do REPLAY o resto é pintado na hora, então o planeta
## final é idêntico ao original (é o mesmo fluxo de pinturas, na mesma ordem).
## ponytail: só o território (nascimentos, expansões, conversões); eventos e clima não aparecem no replay.

## Passo 68: quantos segundos (do replay) o nome de um evento fica na legenda.
@export var event_caption_seconds := 2.0

var playing := false

var _batches: Array = []   # [segundos da partida, owner_id, células, espaçamento]
var _clock := 0.0          # relógio da partida: corre do GO! ao fim do tempo
var _running := false
var _total := 0.0
var _next := 0             # próximo lote a repintar
var _elapsed := 0.0
var _duration := 0.0
var _events: Array = []    # [segundos da partida, nome] de cada evento global anunciado
var _event_name_seen := ""
var _last_warning := 0     # última contagem do aviso: se ela sobe, é um evento novo
var _next_event := 0
var _event_name := ""
var _event_left := 0.0
var _layer: CanvasLayer   # legenda do replay (Passo 67): só existe enquanto ele roda
var _caption: Label


func _ready() -> void:
	EventBus.territory_cells_claimed.connect(func(owner_id: int, cells: PackedVector3Array, spacing: float) -> void:
		_batches.append([_clock, owner_id, cells, spacing]))
	EventBus.global_event_warning.connect(_on_warning)
	EventBus.match_started.connect(func() -> void: _running = true)
	EventBus.match_ended.connect(func() -> void:
		_running = false
		_total = _clock)
	EventBus.match_state_changed.connect(_on_state)


func _process(delta: float) -> void:
	if _running:
		_clock += delta
	if not playing:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_finish()
		return
	var upto := _total * _elapsed / _duration
	_caption.text = "REPLAY  %d:%02d" % [floori(upto / 60.0), int(upto) % 60]
	while _next_event < _events.size() and _events[_next_event][0] <= upto:
		_event_name = _events[_next_event][1]
		_event_left = event_caption_seconds
		_next_event += 1
	if _event_left > 0.0:
		_event_left -= delta
		_caption.text += "
" + _event_name
	while _next < _batches.size() and _batches[_next][0] <= upto:
		_push(_next)
		_next += 1


## Passo 69: clique, toque, ESPAÇO, ENTER ou ESC durante o replay pula para os resultados.
func _unhandled_input(event: InputEvent) -> void:
	if not playing or Services.flow == null:
		return
	var skip: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed
	if event is InputEventKey and event.pressed and not event.echo:
		skip = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
	if skip:
		get_viewport().set_input_as_handled()
		Services.flow.skip_replay()


# O aviso conta os segundos para baixo; quando a contagem sobe (ou o nome muda), um evento novo foi anunciado.
func _on_warning(event_name: String, seconds: int) -> void:
	if _running and (seconds > _last_warning or event_name != _event_name_seen):
		_events.append([_clock, event_name])
	_last_warning = seconds
	_event_name_seen = event_name


func _on_state(state: int) -> void:
	if state == MatchFlow.State.REPLAY:
		_begin()
	elif state > MatchFlow.State.REPLAY and playing:
		_finish()


func _begin() -> void:
	var painter = Services.planet.painter if Services.planet != null else null
	_duration = Services.flow.replay_seconds * Services.flow.pace if Services.flow != null else 0.0
	if painter == null or _batches.is_empty() or _duration <= 0.0:
		return   # sem replay: o planeta final fica como está
	painter.paint_all_now()
	painter.clear()
	_next = 0
	_next_event = 0
	_event_left = 0.0
	_elapsed = 0.0
	playing = true
	_show_caption()


# Pinta o que faltou e devolve o planeta final.
func _finish() -> void:
	playing = false
	if _layer != null:
		_layer.queue_free()
		_layer = null
		_caption = null
	while _next < _batches.size():
		_push(_next)
		_next += 1
	Services.planet.painter.paint_all_now()


func _push(index: int) -> void:
	var batch: Array = _batches[index]
	Services.planet.painter.enqueue(batch[1], batch[2], batch[3])


## Passo 67: legenda no alto da tela com o instante da partida que o replay está mostrando.
func _show_caption() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_caption = Label.new()
	_caption.text = "REPLAY  0:00"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 24.0
	_layer.add_child(_caption)
	add_child(_layer)
