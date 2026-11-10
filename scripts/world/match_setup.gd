class_name MatchSetup
extends Node
## Monta a partida (DD-095): mantém a base e o corredor do jogador do Main e cria os adversários (bots),
## cada um com sua base (nave + domo) e corredor. As civilizações nascem nas 6 "faces de um cubo" do
## planeta, embaralhadas a cada partida. O cubo é inclinado com a diagonal no eixo Y: nenhuma face cai
## sobre um polo (|y| = 0,577), onde a câmera e a grade de territórios sofrem. Roda no _ready, antes
## de a superfície existir: bases e corredores já nascem no lugar certo.
## ponytail: no máximo 6 civilizações (6 faces, 6 fichas de tema); acima disso o Unity sorteava com
## separação mínima — entra com o multiplayer.

@export var world_path := NodePath("../Main")
@export_range(0, 5) var bot_count := 3
@export var home_scene: PackedScene
@export var runner_scene: PackedScene
@export var skip_ceremony := false   # testes/bancadas: pula a abertura de 7 s

# Gira o cubo para a diagonal (1,1,1) apontar para +Y.
var _cube_tilt := Basis(Vector3(-1, 0, 1).normalized(), acos(1.0 / sqrt(3.0)))


func _ready() -> void:
	var world := get_node(world_path)
	var homes: Array[HomeTerritory] = [world.get_node("HomeBase") as HomeTerritory]
	var runners: Array[PlanetRunner] = [world.get_node("Runner") as PlanetRunner]
	for n in bot_count:
		var id := n + 2
		var home := home_scene.instantiate() as HomeTerritory
		home.name = "HomeBase%d" % id
		home.get_node("Civilization").id = id
		var runner := runner_scene.instantiate() as PlanetRunner
		runner.name = "Runner%d" % id
		runner.get_node("Civilization").id = id
		var brain := BotSteering.new()
		brain.name = "Steering"
		brain.ambition = BotSteering.ambition_for(int(Profile.data.get("rating", Profile.RATING_START)))   # Passo 54: bots no nível do jogador
		brain.greed = BotSteering.greed_for(id)   # Passo 62: cobiça por bônus fixa por civilização
		runner.get_node("Steering").free()   # troca o motorista humano pelo cérebro de bot
		runner.add_child(brain)
		homes.append(home)
		runners.append(runner)
		world.add_child(home)
		world.add_child(runner)

	var faces: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	faces.shuffle()
	var yaw := Basis(Vector3.UP, randf() * TAU)   # gira o cubo em torno de Y: varia a posição, mantém |y|
	var planet_radius: float = Services.planet.radius
	for i in homes.size():
		var spot: Vector3 = Services.planet.center + (yaw * _cube_tilt * faces[i]) * planet_radius
		homes[i].global_position = spot
		runners[i].global_position = spot
		if skip_ceremony:
			homes[i].skip_ceremony()
