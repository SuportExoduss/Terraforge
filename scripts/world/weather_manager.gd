class_name WeatherManager
extends Node
## Clima global (CL-002..005, DD-086..088): chuva, neblina, aurora e tempestade visual, guiados pelo cronômetro.
## A partida tem 6 janelas de clima; a condição de cada uma sai da SEMENTE (servidor e clientes calculam o mesmo — nada
## precisa ser enviado) e entra/sai com fade suave. A primeira janela é sempre limpa; aurora só aparece na metade
## noturna. Evento global em execução SOBREPÕE o clima (ele some em `override_seconds` e volta depois — DD-087).
## Legibilidade primeiro: a neblina tem teto de densidade e chuva/aurora são só riscos aditivos finos, nunca uma cortina.
## ponytail: o visual é UM retângulo de tela com um shader (riscos de chuva, faixas de aurora, relâmpago) + a névoa do
## Environment; partículas 3D e solo molhado ficam para quando houver arte.

const WINDOWS := 6
const FADE_SECONDS := 15.0           # entrada e saída de cada janela
const FOG_MAX := 0.002               # névoa exponencial: ~23% de véu na distância da câmera até o planeta
const RAIN_MAX := 0.8
const AURORA_MAX := 0.6
const FLASH_MAX := 0.12
const DAY_CONDITIONS := ["clear", "rain", "fog", "storm"]
const NIGHT_FIRST_WINDOW := 3        # aurora só da janela 3 em diante (noite)
const FOG_SHARE := {"fog": 1.0, "storm": 0.6, "rain": 0.35}

const SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float rain = 0.0;
uniform float aurora = 0.0;
uniform float flash = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec3 add = vec3(flash);
	if (rain > 0.0) {
		vec2 uv = UV * vec2(120.0, 14.0);
		uv.x += uv.y * 0.35;
		uv.y -= TIME * 9.0;
		vec2 id = floor(uv);
		vec2 f = fract(uv);
		float drop = step(0.93, hash(id));
		float line = 1.0 - smoothstep(0.05, 0.2, abs(f.x - 0.5));
		add += vec3(0.7, 0.8, 1.0) * drop * line * (1.0 - f.y) * 0.5 * rain;
	}
	if (aurora > 0.0) {
		float wave = sin(UV.x * 6.0 + TIME * 0.4) * 0.05 + sin(UV.x * 13.0 - TIME * 0.25) * 0.025;
		float band = exp(-pow((UV.y - 0.18 - wave) * 9.0, 2.0)) + 0.6 * exp(-pow((UV.y - 0.30 - wave * 1.4) * 7.0, 2.0));
		vec3 tint = mix(vec3(0.1, 1.0, 0.55), vec3(0.6, 0.3, 1.0), smoothstep(0.1, 0.4, UV.y));
		add += tint * band * 0.35 * aurora;
	}
	COLOR = vec4(add, 1.0);
}
"""

@export var weather_seed: int = 20260709   # a semente da partida (multiplayer: vem do servidor)
@export var override_seconds := 3.0

var condition := "clear"   # condição da janela atual
var intensity := 0.0       # 0..1 já com o fade da janela e a sobreposição de evento
var flashes := 0           # relâmpagos já disparados (o smoke confere por aqui)

var _elapsed := 0.0
var _event_active := false
var _event_factor := 1.0
var _flash := 0.0
var _next_flash := 6.0
var _material: ShaderMaterial


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1   # sobre o 3D, sob o HUD
	var screen := ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = Shader.new()
	_material.shader.code = SHADER
	screen.material = _material
	layer.add_child(screen)
	add_child(layer)
	EventBus.match_started.connect(func(): _elapsed = 0.0)
	EventBus.match_clock_changed.connect(_on_clock)
	EventBus.global_event_active_changed.connect(func(active): _event_active = active)


## Condição da janela `window` (0..WINDOWS-1) para uma semente.
static func condition_for(seed_value: int, window: int) -> String:
	if window <= 0:
		return "clear"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + window * 7919
	var options: Array = DAY_CONDITIONS.duplicate()
	if window >= NIGHT_FIRST_WINDOW:
		options.append("aurora")
	return options[rng.randi() % options.size()]


## Condição e intensidade (0..1, só do fade da janela) aos `elapsed` segundos de uma partida de `duration` s.
static func state_at(seed_value: int, elapsed: float, duration: float) -> Dictionary:
	var length := duration / WINDOWS
	var window := clampi(int(elapsed / length), 0, WINDOWS - 1)
	var inside := clampf(elapsed - window * length, 0.0, length)
	var fade := smoothstep(0.0, 1.0, minf(inside, length - inside) / FADE_SECONDS)
	var picked := condition_for(seed_value, window)
	return {"condition": picked, "intensity": 0.0 if picked == "clear" else fade}


## Dispara um relâmpago (tempestade): clarão curto na tela.
func strike() -> void:
	flashes += 1
	_flash = 1.0


func _on_clock(seconds_left: int) -> void:
	var timer := get_tree().get_first_node_in_group("match_timer") as MatchTimer
	if timer:
		_elapsed = timer.duration_seconds - seconds_left


func _process(delta: float) -> void:
	var timer := get_tree().get_first_node_in_group("match_timer") as MatchTimer
	var duration: float = timer.duration_seconds if timer else 600.0
	_event_factor = move_toward(_event_factor, 0.0 if _event_active else 1.0, delta / maxf(override_seconds, 0.01))
	var state := state_at(weather_seed, _elapsed, duration)
	condition = state["condition"]
	intensity = state["intensity"] * _event_factor
	_flash = maxf(0.0, _flash - delta * 4.0)
	if condition == "storm" and intensity > 0.5:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_next_flash = randf_range(5.0, 12.0)
			strike()
	_apply()


func _apply() -> void:
	var wet := intensity if condition in ["rain", "storm"] else 0.0
	_material.set_shader_parameter("rain", wet * RAIN_MAX)
	_material.set_shader_parameter("aurora", intensity * AURORA_MAX if condition == "aurora" else 0.0)
	_material.set_shader_parameter("flash", _flash * FLASH_MAX)
	var world := get_node_or_null("../Main/WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		var env := world.environment
		var density: float = FOG_MAX * FOG_SHARE.get(condition, 0.0) * intensity
		env.fog_enabled = density > 0.0
		env.fog_density = density
		var daylight := clampf((env.ambient_light_energy - 0.35) / 0.25, 0.0, 1.0)   # acompanha o ciclo dia/noite
		env.fog_light_color = Color(0.55, 0.6, 0.7) * (0.25 + 0.75 * daylight)
