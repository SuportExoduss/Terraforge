extends Node3D
## Passo 117 (DD-157): coroa dourada flutuando sobre quem lidera o domínio do planeta. Todo mundo vê: o líder vira o alvo
## (lição do Paper.io: coroa no topo atrai a caça e dá motivo para defender). Só mostra; não muda regra nenhuma.
## Líder = 1º vivo do ranking, com pelo menos MIN_SHARE do planeta e domínio ESTRITAMENTE maior que o do 2º (empate = sem coroa).
## ponytail: coroa de 1 anel + 5 pontas (primitivas), sem modelo; trocar por arte quando houver.

const MIN_SHARE := 0.08       # antes disso ninguém "lidera" de verdade (começo de partida)
const CHECK_SECONDS := 0.25   # o ranking é barato, mas não precisa de 60 vezes por segundo
const LIFT := 3.5             # acima da superfície: a cabeça do corredor fica em +2
const SIZE := 1.6             # a coroa precisa ler de longe (câmera atrás do corredor)
const SPIN := 1.6             # rad/s
const BOB := 0.18             # amplitude do sobe-e-desce

var leader_id := -1           # -1 = ninguém coroado
var _runner: Node3D
var _crown: Node3D
var _since := 0.0
var _time := 0.0


func _ready() -> void:
	_crown = _build()
	_crown.visible = false
	add_child(_crown)


func _process(delta: float) -> void:
	_since += delta
	if _since >= CHECK_SECONDS:
		_since = 0.0
		_pick()
	var planet := Services.planet
	if _runner == null or not is_instance_valid(_runner) or planet == null:
		_crown.visible = false
		return
	_time += delta
	var up := (_runner.global_position - planet.center).normalized()
	var bob := 0.0 if Settings.reduced_motion() else sin(_time * 3.0) * BOB
	var right := up.cross(Vector3.FORWARD if absf(up.y) > 0.99 else Vector3.UP).normalized()
	var basis := Basis(right, up, right.cross(up)).rotated(up, _time * SPIN if not Settings.reduced_motion() else 0.0).scaled(Vector3.ONE * SIZE)
	_crown.global_transform = Transform3D(basis, planet.center + up * (planet.get_surface_radius(up) + LIFT + bob))
	_crown.visible = true


func _pick() -> void:
	var stats := Services.stats
	var id := -1
	if stats != null:
		var order: Array = stats.ranking()
		if not order.is_empty() and not stats.is_eliminated(order[0]) and stats.dominance(order[0]) >= MIN_SHARE:
			var second: float = stats.dominance(order[1]) if order.size() > 1 and not stats.is_eliminated(order[1]) else 0.0
			if stats.dominance(order[0]) > second:
				id = order[0]
	if id == leader_id and (id == -1 or (_runner != null and is_instance_valid(_runner))):
		return
	leader_id = id
	_runner = null
	for node in get_tree().get_nodes_in_group("runners"):
		if node.get_node("Civilization").id == id:
			_runner = node
	if _runner == null:
		leader_id = -1   # líder sem corredor na cena (ex.: bancada): sem coroa


func _build() -> Node3D:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.25)
	gold.metallic = 0.6
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.15)
	gold.emission_energy_multiplier = 0.9
	var crown := Node3D.new()
	crown.name = "Crown"
	var band := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.62
	ring.material = gold
	band.mesh = ring
	crown.add_child(band)
	for i in 5:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.16
		cone.height = 0.6
		cone.material = gold
		spike.mesh = cone
		var a := TAU * i / 5.0
		spike.position = Vector3(cos(a) * 0.52, 0.3, sin(a) * 0.52)
		crown.add_child(spike)
	return crown
