class_name ObstacleSystem
extends Node
## SYS-007: obstáculos. Os obstáculos SÃO os slots ambientais sólidos (cacto, rocha grande, estrutura grande,
## landmark — ver EnvironmentSlotSystem.SOLID_RADIUS): por isso já trocam sozinhos com o dono do chão (animação
## de saída/entrada do DD-035) e já "pertencem" à civilização. Este nó só faz dois trabalhos: (1) tirar os
## corredores de dentro deles e curvar o rumo para contornar — sem travar a fluidez; (2) quando um evento
## (meteoro) arrasa uma área, os obstáculos dali somem por um tempo e depois voltam.
## Este nó precisa vir DEPOIS dos corredores na árvore (empurra o que eles já andaram neste quadro).
## ponytail: sem perigos ainda (lava/alagamento chegam com os eventos Vulcão/Tsunami, com aviso visual);
## o rumo é suavizado só quando o corredor anda de frente para o obstáculo.

@export var slots_path := NodePath("../Main/Slots")
@export var body_radius := 0.6           # "largura" do corredor para a colisão
@export var event_clear_seconds := 25.0  # quanto tempo o meteoro deixa a área limpa (= cicatriz, DD-108)
@export var turn_rate := 4.0             # quão rápido o rumo se curva em volta do obstáculo (1/s)

@onready var _slots := get_node(slots_path) as EnvironmentSlotSystem


func _ready() -> void:
	EventBus.radial_damage.connect(_on_radial_damage)


func _process(delta: float) -> void:
	var planet := Services.planet
	if planet == null or not planet.surface_ready:
		return
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		if not runner.is_active_in_field():
			continue
		var push := _slots.push_out(runner.global_position, body_radius)
		if push == Vector3.ZERO:
			continue
		runner.global_position += push
		var up := (runner.global_position - planet.center).normalized()
		var away := push.slide(up).normalized()
		if away != Vector3.ZERO and runner.forward.dot(away) < 0.0:   # andando de frente para ele: escolhe o lado
			var side := up.cross(away)
			if runner.forward.dot(side) < 0.0:
				side = -side
			runner.forward = runner.forward.slerp(side, minf(1.0, turn_rate * delta)).normalized()


# O raio médio do meteoro (6/12/20) é a zona arrasada.
func _on_radial_damage(center: Vector3, _inner_radius: float, _inner_damage: int, _inner_returns: bool,
		mid_radius: float, _mid_damage: int, _outer_radius: float, _outer_damage: int) -> void:
	_slots.suppress_around(center, mid_radius, event_clear_seconds)
