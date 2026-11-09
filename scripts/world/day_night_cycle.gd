class_name DayNightCycle
extends Node
## Ciclo dia/noite e iluminação global (CL-001, CL-006), guiado pelo cronômetro da partida (10 min):
## dia → pôr do sol (60%) → noite (80%). Cada segundo do relógio mexe um tiquinho na luz, então a transição é gradual.
## Regras do GDMD: nunca reduz drasticamente a visibilidade (pisos de luz abaixo) e a fase é função só do relógio —
## servidor e clientes, ou uma partida recuperada, chegam na mesma luz.
## Mexe só no Sol e no ambiente da cena Main (o minimapa tem o próprio ambiente fixo, de propósito: leitura estratégica).
## ponytail: o Sol não gira, só muda de cor/energia; céu estrelado fica para o clima (Passo 32).

const AMBIENT_FLOOR := 0.35   # energia de luz ambiente mínima: os biomas continuam legíveis de noite
const SUN_FLOOR := 0.4
# fase da partida (0..1) -> energia do Sol, cor do Sol, energia ambiente, cor ambiente, cor do fundo
const KEYS := [
	[0.0, 1.2, Color(1.0, 1.0, 1.0), 0.6, Color(0.7, 0.75, 0.85), Color(0.04, 0.06, 0.13)],    # dia = o visual de sempre
	[0.4, 1.2, Color(1.0, 1.0, 1.0), 0.6, Color(0.7, 0.75, 0.85), Color(0.04, 0.06, 0.13)],
	[0.6, 0.9, Color(1.0, 0.62, 0.35), 0.5, Color(0.85, 0.6, 0.55), Color(0.14, 0.07, 0.11)],  # pôr do sol: luz quente
	[0.8, 0.45, Color(0.5, 0.6, 1.0), 0.4, Color(0.45, 0.55, 0.85), Color(0.01, 0.02, 0.07)],  # noite: luz fria e azulada
	[1.0, 0.45, Color(0.5, 0.6, 1.0), 0.4, Color(0.45, 0.55, 0.85), Color(0.01, 0.02, 0.07)],
]

var phase := 0.0   # 0 = início da partida, 1 = fim

var _sun: DirectionalLight3D
var _env: Environment


func _ready() -> void:
	_sun = get_node_or_null("../Main/Sun")
	var world: WorldEnvironment = get_node_or_null("../Main/WorldEnvironment")
	if world:
		world.environment = world.environment.duplicate()   # o recurso da cena é compartilhado: não o altere
		_env = world.environment
	EventBus.match_started.connect(func(): apply(0.0))
	EventBus.match_clock_changed.connect(_on_clock)


## Luz de uma fase da partida (0..1), interpolada entre as chaves.
static func sample(at: float) -> Dictionary:
	at = clampf(at, 0.0, 1.0)
	var i := 1
	while i < KEYS.size() - 1 and at > KEYS[i][0]:
		i += 1
	var a: Array = KEYS[i - 1]
	var b: Array = KEYS[i]
	var t := inverse_lerp(a[0], b[0], at)
	return {
		"sun_energy": maxf(SUN_FLOOR, lerpf(a[1], b[1], t)),
		"sun_color": (a[2] as Color).lerp(b[2], t),
		"ambient_energy": maxf(AMBIENT_FLOOR, lerpf(a[3], b[3], t)),
		"ambient_color": (a[4] as Color).lerp(b[4], t),
		"background": (a[5] as Color).lerp(b[5], t),
	}


func apply(at: float) -> void:
	phase = clampf(at, 0.0, 1.0)
	var light := sample(phase)
	if _sun:
		_sun.light_energy = light["sun_energy"]
		_sun.light_color = light["sun_color"]
	if _env:
		_env.ambient_light_energy = light["ambient_energy"]
		_env.ambient_light_color = light["ambient_color"]
		_env.background_color = light["background"]


func _on_clock(seconds_left: int) -> void:
	var timer := get_tree().get_first_node_in_group("match_timer") as MatchTimer
	if timer:
		apply(1.0 - seconds_left / timer.duration_seconds)
