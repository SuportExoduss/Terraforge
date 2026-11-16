class_name PerfMeter
extends Node
## Medidor de desempenho (OP-001..006 / DD-092): guarda o tempo dos últimos quadros e, com F3, mostra na tela FPS, tempo
## médio/pior quadro, objetos na tela e nós vivos. "Performance é prioridade contínua": o teste lê estes números e a
## meta é a do DD-124 (45+ FPS no notebook => quadro de até ~22 ms em 95% dos casos).
## ponytail: anel de 240 quadros (4 s a 60 FPS) e um Label; sem gráfico nem exportação — vira ferramenta de QA quando precisar.

const WINDOW := 240
const BUDGET_MS := 1000.0 / 45.0
const OVERLAY_SECONDS := 0.25   # o texto é refeito poucas vezes por segundo (o próprio medidor não pode pesar)
# Resolução adaptativa (celular): quadro médio lento = abaixa a resolução 3D em passos de 5%; folgado e calmo = devolve.
const GOVERN_SECONDS := 2.0
const SLOW_MS := 23.0           # ~43 FPS, logo abaixo da meta do DD-124
const FAST_MS := 18.0
const CALM_SECONDS := 8.0       # depois de baixar, espera isto antes de tentar subir (não fica oscilando)
const MIN_SCALE := 0.5
const SCALE_STEP := 0.05

var overlay_visible := false
var governor_on := OS.has_feature("mobile")   # no PC o jogador escolhe a qualidade; no celular o medidor protege a fluidez

var _frames := PackedFloat32Array()   # ms por quadro, em anel
var _next := 0
var _label: Label
var _since_text := 0.0
var _gov_sum := 0.0
var _gov_frames := 0
var _gov_time := 0.0
var _calm := 0.0


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


func _exit_tree() -> void:
	if governor_on:
		Settings.apply_all()   # a partida acabou: menu e telas voltam à resolução escolhida


## Próxima resolução 3D: cai um passo se o quadro médio passa de SLOW_MS (até MIN_SCALE); sobe um passo (até `ceiling`,
## a da qualidade escolhida) se está abaixo de FAST_MS e `calm` (não caiu há CALM_SECONDS).
static func next_scale(current: float, ceiling: float, average_ms: float, calm: bool) -> float:
	if average_ms > SLOW_MS:
		return maxf(MIN_SCALE, current - SCALE_STEP)
	if calm and average_ms < FAST_MS:
		return minf(ceiling, current + SCALE_STEP)
	return current


func _govern(delta: float) -> void:
	_gov_sum += minf(delta * 1000.0, 50.0)   # um engasgo isolado (carga de cena) não derruba a resolução
	_gov_frames += 1
	_gov_time += delta
	_calm += delta
	if _gov_time < GOVERN_SECONDS:
		return
	var window := get_tree().root
	var ceiling: float = Settings.QUALITY_SCALE[clampi(int(Settings.get_value("quality")), 0, Settings.QUALITY_NAMES.size() - 1)]
	var next := next_scale(window.scaling_3d_scale, ceiling, _gov_sum / _gov_frames, _calm >= CALM_SECONDS)
	if next < window.scaling_3d_scale:
		_calm = 0.0
	window.scaling_3d_scale = next
	_gov_sum = 0.0
	_gov_frames = 0
	_gov_time = 0.0


func _process(delta: float) -> void:
	record(delta * 1000.0)
	if governor_on:
		_govern(delta)
	if overlay_visible:
		_since_text += delta
		if _since_text >= OVERLAY_SECONDS:
			_since_text = 0.0
			_label.text = report()
