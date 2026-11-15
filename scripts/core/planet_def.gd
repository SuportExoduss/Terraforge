class_name PlanetDef
extends Resource
## DD-143: o planeta é um DADO. Raio, adversários e duração da partida vêm daqui; a densidade de células do território
## e de slots ambientais é a do planeta Médio (raio 100), então o ritmo da conquista por área não muda com o tamanho.
## O menu escolhe um e o põe em `Services.match_def`; sem ele (testes, servidor) a partida usa os padrões das cenas.
## ponytail: o catálogo mora aqui como dado de script, sem .tres; cada planeta novo é uma linha em `catalog()`.
## O GRANDE (raio ~140, 6 civilizações) só entra depois do teste no celular (DD-138): mais células custam quadros.

const BASE_RADIUS := 100.0
const BASE_CELLS := 20000
const BASE_SLOTS := 720

@export var id := "medio"
@export var display_name := "Médio"
@export var radius := BASE_RADIUS
@export var bots := 3
@export var duration_seconds := 600.0
@export var calm := false       # Passo 106: bots mansos (nunca caçam rastro, saídas curtas)
@export var tutorial := false   # Passo 106: a partida mostra as dicas de uma frase (TutorialCoach)
@export var biome := "deserto"   # Passo 124 (DD-164): aparência da terra neutra; só visual, nunca muda a regra
@export var blurb := ""          # Passo 125: uma frase de identidade para a tela de escolha de planeta

## Passo 124: cada bioma é um par de cores da terra (escura -> clara, espalhadas pelas manchas do shader), a cor da água e o brilho
## da atmosfera no menu. "deserto" não está aqui: é o visual de sempre (a textura do modelo + as manchas do Passo 121).
const LOOKS := {
	"gelo": {"dark": Color(0.55, 0.70, 0.86), "light": Color(0.96, 0.99, 1.0), "water": Color(0.10, 0.36, 0.55), "air": Color(0.55, 0.90, 1.0)},
	"vulcao": {"dark": Color(0.07, 0.06, 0.06), "light": Color(0.30, 0.20, 0.17), "water": Color(0.95, 0.30, 0.05), "air": Color(1.0, 0.45, 0.2)},
}
const DEFAULT_AIR := Color(0.35, 0.65, 1.0)


func area_scale() -> float:
	return (radius / BASE_RADIUS) * (radius / BASE_RADIUS)


func cell_count() -> int:
	return roundi(BASE_CELLS * area_scale())


func slot_count() -> int:
	return roundi(BASE_SLOTS * area_scale())


func size_percent() -> int:   # Passo 125: tamanho em % da área do Médio (o que o jogador sente: mais chão = partida maior)
	return roundi(area_scale() * 100.0)


func summary() -> String:
	return "%s · %d min · %d jogadores" % [display_name, roundi(duration_seconds / 60.0), bots + 1]


static func make(def_id: String, label: String, planet_radius: float, bot_count: int, seconds: float) -> PlanetDef:
	var def := PlanetDef.new()
	def.id = def_id
	def.display_name = label
	def.radius = planet_radius
	def.bots = bot_count
	def.duration_seconds = seconds
	return def


static func catalog() -> Array[PlanetDef]:
	return [
		_with(make("medio", "Médio", 100.0, 3, 600.0), "deserto", "O clássico: deserto e partida cheia."),   # o planeta de sempre (DD-111)
		_with(make("pequeno", "Pequeno", 60.0, 2, 240.0), "deserto", "Partida rápida: dá para uma pausa de café."),   # porta de entrada e treino
		_with(make("gelo", "Gelo", 80.0, 3, 360.0), "gelo", "Terra branca e água gelada. Tamanho médio."),   # Passo 124
		_with(make("vulcao", "Vulcão", 100.0, 3, 480.0), "vulcao", "Cinza e lava: o planeta grande dos veteranos."),
	]


static func _with(def: PlanetDef, biome_id: String, text: String) -> PlanetDef:
	def.biome = biome_id
	def.blurb = text
	return def


## Passo 125: as 3 cores que identificam o bioma na tela de escolha (terra escura, terra clara, água).
static func swatch(biome_id: String) -> Array[Color]:
	var look: Dictionary = LOOKS.get(biome_id, {})
	var colors: Array[Color] = []
	colors.append(look.get("dark", Color(0.62, 0.42, 0.24)))
	colors.append(look.get("light", Color(0.88, 0.70, 0.46)))
	colors.append(look.get("water", Color(0.16, 0.42, 0.74)))
	return colors


## Passo 124: entrega ao shader da superfície a aparência do bioma (a = 0 desliga: o deserto fica como era).
static func apply_look(material: ShaderMaterial, def: PlanetDef) -> void:
	var look: Dictionary = LOOKS.get(def.biome, {}) if def != null else {}
	var on := 1.0 if not look.is_empty() else 0.0
	var dark: Color = look.get("dark", Color.BLACK)
	var water: Color = look.get("water", Color.BLACK)
	material.set_shader_parameter("look_dark", Color(dark.r, dark.g, dark.b, on))
	material.set_shader_parameter("look_light", look.get("light", Color.WHITE))
	material.set_shader_parameter("look_water", Color(water.r, water.g, water.b, on))


## Cor do brilho da atmosfera do planeta no menu.
static func air_color(biome_id: String) -> Color:
	return LOOKS.get(biome_id, {}).get("air", DEFAULT_AIR)


## Passo 106 (DD-146): a PRIMEIRA partida de quem nunca jogou. Fora do catálogo (o jogador não escolhe): planeta pequeno,
## 1 bot manso e dicas na hora certa; vale enquanto `Profile.data["matches"]` for 0.
static func training() -> PlanetDef:
	var def := make("treino", "Treino", 60.0, 1, 180.0)
	def.calm = true
	def.tutorial = true
	return def


static func by_id(def_id: String) -> PlanetDef:
	for def in catalog():
		if def.id == def_id:
			return def
	return catalog()[0]
