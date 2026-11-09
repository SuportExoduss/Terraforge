class_name FirstConquestBurst
extends Node3D
## DD-013: a primeira conquista do jogador gera forte recompensa visual (Cap.03 P03, 20–30 s). Anel de luz que se abre no
## chão + chuva de faíscas subindo do centro da área. Uma vez por partida, só o jogador local, sem texto (DD-014).
## ponytail: dourado fixo para qualquer civilização; usar a cor do tema do jogador se quiserem identidade própria.

const COLOR := Color(1.0, 0.85, 0.35)
const RING_SECONDS := 1.4
const RING_RADIUS := 14.0     # raio final do anel, em unidades do planeta
const LIFETIME := 3.0         # depois disso o efeito se apaga sozinho

var fired := false
var _cells: Dictionary = {}   # dono -> células da última conquista (o sinal do circuito vem logo em seguida)


func _ready() -> void:
	EventBus.territory_cells_claimed.connect(func(id: int, cells: PackedVector3Array, _spacing: float) -> void: _cells[id] = cells)
	EventBus.territory_loop_claimed.connect(_on_loop_claimed)


func _on_loop_claimed(owner_id: int, new_cells: int) -> void:
	var planet := Services.planet
	var cells: PackedVector3Array = _cells.get(owner_id, PackedVector3Array())
	if fired or owner_id != Civilization.PLAYER_ID or new_cells < MatchStats.MIN_LOOP_CELLS or planet == null or cells.is_empty():
		return
	fired = true
	var sum := Vector3.ZERO
	for cell in cells:
		sum += (cell - planet.center).normalized()
	var up := sum.normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.y) > 0.99 else Vector3.UP).normalized()
	var spot := Node3D.new()   # "cima" = para fora do planeta
	spot.name = "Spot"
	spot.transform = Transform3D(Basis(right, up, right.cross(up)), planet.center + up * (planet.get_surface_radius(up) + 0.3))
	add_child(spot)
	_ring(spot)
	_sparks(spot)
	get_tree().create_timer(LIFETIME).timeout.connect(spot.queue_free)


func _unshaded() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = COLOR
	return material


func _ring(spot: Node3D) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	mesh.material = _unshaded()
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = mesh
	ring.scale = Vector3.ONE
	spot.add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * RING_RADIUS, RING_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mesh.material, "albedo_color:a", 0.0, RING_SECONDS)


func _sparks(spot: Node3D) -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = _unshaded()
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.mesh = ball
	sparks.amount = 90
	sparks.lifetime = 1.6
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.local_coords = true          # gravidade e direção no espaço do ponto: "cima" = para fora do planeta
	sparks.direction = Vector3.UP
	sparks.spread = 55.0
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 14.0
	sparks.gravity = Vector3(0, -7, 0)
	spot.add_child(sparks)
	sparks.emitting = true
