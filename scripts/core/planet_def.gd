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


func area_scale() -> float:
	return (radius / BASE_RADIUS) * (radius / BASE_RADIUS)


func cell_count() -> int:
	return roundi(BASE_CELLS * area_scale())


func slot_count() -> int:
	return roundi(BASE_SLOTS * area_scale())


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
		make("medio", "Médio", 100.0, 3, 600.0),   # o planeta de sempre (DD-111)
		make("pequeno", "Pequeno", 60.0, 2, 240.0),   # partida rápida: porta de entrada e treino
	]


static func by_id(def_id: String) -> PlanetDef:
	for def in catalog():
		if def.id == def_id:
			return def
	return catalog()[0]
