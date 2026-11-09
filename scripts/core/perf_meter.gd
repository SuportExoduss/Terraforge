class_name PerfMeter
extends Node
## Medidor de desempenho (OP-001..006 / DD-092): guarda o tempo dos últimos quadros e, com F3, mostra na tela FPS, tempo
## médio/pior quadro, objetos na tela e nós vivos. "Performance é prioridade contínua": o teste lê estes números e a
## meta é a do DD-124 (45+ FPS no notebook => quadro de até ~22 ms em 95% dos casos).
## ponytail: anel de 240 quadros (4 s a 60 FPS) e um Label; sem gráfico nem exportação — vira ferramenta de QA quando precisar.

const WINDOW := 240
const BUDGET_MS := 1000.0 / 45.0
const OVERLAY_SECONDS := 0.25   # o texto é refeito poucas vezes por segundo (o próprio medidor não pode pesar)

var overlay_visible := false

var _frames := PackedFloat32Array()   # ms por quadro, em anel
var _next := 0
var _label: Label
var _since_text := 0.0


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.position = Vector2(8.0, 8.0)
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(_label)
	add_child(layer)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		toggle_overlay()


func toggle_overlay() -> void:
	overlay_visible = not overlay_visible
	_label.visible = overlay_visible
	_since_text = OVERLAY_SECONDS   # já atualiza no próximo quadro


func record(ms: float) -> void:
	if _frames.size() < WINDOW:
		_frames.append(ms)
	else:
		_frames[_next] = ms
	_next = (_next + 1) % WINDOW


func sample_count() -> int:
	return _frames.size()


func average_ms() -> float:
	if _frames.is_empty():
		return 0.0
	var total := 0.0
	for ms in _frames:
		total += ms
	return total / _frames.size()


func worst_ms() -> float:
	var worst := 0.0
	for ms in _frames:
		worst = maxf(worst, ms)
	return worst


## Tempo de quadro que 95% dos quadros respeitam (a média esconde os engasgos).
func p95_ms() -> float:
	if _frames.is_empty():
		return 0.0
	var sorted := _frames.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)]


func fps() -> float:
	var average := average_ms()
	return 1000.0 / average if average > 0.0 else 0.0


func within_budget() -> bool:
	return p95_ms() <= BUDGET_MS


func report() -> String:
	return "%d FPS · quadro %.1f ms (p95 %.1f, pior %.1f) · %d objetos na tela · %d nós" % [
			roundi(fps()), average_ms(), p95_ms(), worst_ms(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]


func _process(delta: float) -> void:
	record(delta * 1000.0)
	if overlay_visible:
		_since_text += delta
		if _since_text >= OVERLAY_SECONDS:
			_since_text = 0.0
			_label.text = report()
