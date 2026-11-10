class_name MatchReplay
extends Node
## Replay cinematográfico (cap. 03, parte 11; DD-037: "o replay é parte da recompensa"). Guarda cada lote de células
## conquistadas com o relógio da partida e, no estado REPLAY (MatchFlow), repinta o planeta do zero em velocidade
## acelerada: a partida inteira cabe em replay_seconds. Ao sair do REPLAY o resto é pintado na hora, então o planeta
## final é idêntico ao original (é o mesmo fluxo de pinturas, na mesma ordem).
## ponytail: só o território (nascimentos, expansões, conversões); eventos e clima não aparecem no replay.

var playing := false

var _batches: Array = []   # [segundos da partida, owner_id, células, espaçamento]
var _clock := 0.0          # relógio da partida: corre do GO! ao fim do tempo
var _running := false
var _total := 0.0
var _next := 0             # próximo lote a repintar
var _elapsed := 0.0
var _duration := 0.0
var _layer: CanvasLayer   # legenda do replay (Passo 67): só existe enquanto ele roda
var _caption: Label


func _ready() -> void:
	EventBus.territory_cells_claimed.connect(func(owner_id: int, cells: PackedVector3Array, spacing: float) -> void:
		_batches.append([_clock, owner_id, cells, spacing]))
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
	while _next < _batches.size() and _batches[_next][0] <= upto:
		_push(_next)
		_next += 1


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
