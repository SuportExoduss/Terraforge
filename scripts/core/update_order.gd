class_name UpdateOrder
extends Node
## Ordem de atualização determinística (Cap.05 P07, DD-073). Todo módulo que atualiza a cada quadro entra numa FASE e a
## fase vira process_priority: Entrada → Gameplay → Rede → Física → IA → Mundo → Interface → Áudio → Renderização.
## A classe do módulo decide a fase (subclasses herdam: Tsunami/Vulcão... são GlobalEvent => Mundo). Ninguém precisa
## declarar nada: este nó, dentro da partida, aplica a tabela aos nós que já existem e aos que entrarem depois.
## Nós que não estão na tabela ficam como estavam (prioridade 0, ordem da árvore).
## ponytail: tabela fixa por classe; módulo novo com _process entra numa linha aqui.

enum Phase { INPUT, GAMEPLAY, NETWORK, PHYSICS, AI, WORLD, UI, AUDIO, RENDER }

## Menor prioridade roda primeiro. A renderização continua em 100 (valor que as câmeras já usavam).
const PRIORITY: Array[int] = [-80, -70, -60, -50, -40, -30, -20, -10, 100]

const PHASE_OF := {
	"PlayerSteering": Phase.INPUT,
	"PlanetRunner": Phase.GAMEPLAY, "RunnerTrail": Phase.GAMEPLAY, "TrailCutSensor": Phase.GAMEPLAY,
	"Health": Phase.GAMEPLAY, "HomeTerritory": Phase.GAMEPLAY, "TerritoryMap": Phase.GAMEPLAY,
	"MatchTimer": Phase.GAMEPLAY, "MatchFlow": Phase.GAMEPLAY, "MatchReplay": Phase.GAMEPLAY,
	"BonusSystem": Phase.GAMEPLAY,
	"NetSession": Phase.NETWORK, "MatchServer": Phase.NETWORK,
	"BotSteering": Phase.AI, "DefenderSystem": Phase.AI,
	"GlobalEvent": Phase.WORLD, "MeteorEventSystem": Phase.WORLD, "ObstacleSystem": Phase.WORLD,
	"EnvironmentSlotSystem": Phase.WORLD, "TerritoryPainter": Phase.WORLD,
	"WeatherManager": Phase.WORLD, "DayNightCycle": Phase.WORLD,
	"Hud": Phase.UI, "MinimapMarkers": Phase.UI,
	"AudioDirector": Phase.AUDIO, "MusicDirector": Phase.AUDIO,
	"RunnerCamera": Phase.RENDER, "MinimapCamera": Phase.RENDER, "ContemplationCamera": Phase.RENDER,
	"PerfMeter": Phase.RENDER,
}


## A fase do nó (procura a classe dele e depois as classes-base), ou -1 se ele não está na tabela.
static func phase_of(node: Node) -> int:
	var script: Script = node.get_script()
	while script != null:
		var phase: Variant = PHASE_OF.get(script.get_global_name())
		if phase != null:
			return phase
		script = script.get_base_script()
	return -1


## Aplica a fase ao nó; devolve se ele estava na tabela.
static func apply_to(node: Node) -> bool:
	var phase := phase_of(node)
	if phase < 0:
		return false
	node.process_priority = PRIORITY[phase]
	node.process_physics_priority = PRIORITY[phase]
	return true


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_parent().find_children("*", "", true, false):
		apply_to(node)


func _on_node_added(node: Node) -> void:
	if node.get_script() != null:
		apply_to(node)
