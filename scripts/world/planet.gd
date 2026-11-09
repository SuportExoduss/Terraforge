class_name Planet
extends Node3D
## O planeta. A esfera matemática (radius) rege territórios e órbitas; o TERRENO VISUAL (modelo
## filho "Model") rege onde os pés tocam: get_surface_radius sonda o relevo com um raio físico vindo
## do espaço, para ninguém flutuar sobre vales nem afundar em morros.

@export var radius: float = 100.0

const OCCLUDER_PROBES := 96
const OCCLUDER_MARGIN := 0.9
const GOLDEN_ANGLE := 2.39996323   # radianos

## O pintor de território soma a elevação do bioma (DD-121); é ligado na etapa do território.
var painter: Node = null
signal surface_became_ready

var surface_ready := false

var center: Vector3:
	get:
		return global_position

var _has_colliders := false
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	Services.planet = self
	_normalize_model()
	_prepare_colliders()
	# O corpo físico só entra no mundo depois de 1-2 frames de física.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_add_occluder()
	surface_ready = true
	surface_became_ready.emit()


func _exit_tree() -> void:
	if Services.planet == self:
		Services.planet = null


func get_surface_radius(surface_direction: Vector3) -> float:
	var elevation: float = painter.get_elevation_at(surface_direction) if painter != null else 0.0
	if not _has_colliders:
		return radius + elevation
	var dir := surface_direction.normalized()
	var probe := radius * 1.5
	_query.from = center + dir * probe
	_query.to = center
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty():
		return radius + elevation
	return ((hit["position"] as Vector3) - center).length() + elevation


# O modelo do Tripo vem em escala própria: ajusta para que o raio dele seja `radius`.
func _normalize_model() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	var box := ModelUtils.local_aabb(model)
	var half := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.5
	if half > 0.0:
		model.scale *= radius / half


## OP-002/DD-093: uma esfera oclusora INSCRITA no terreno (o menor raio sondado, com folga) faz o motor não desenhar o
## que está atrás do planeta. Como cabe inteira dentro do relevo, nunca esconde nada que o jogador veja.
## ponytail: 96 sondas fixas; relevo mais fino que o espaçamento entre elas é coberto pela folga de 10%.
func _add_occluder() -> void:
	var inscribed := radius
	if _has_colliders:
		var space := get_world_3d().direct_space_state
		for i in OCCLUDER_PROBES:
			var y := 1.0 - 2.0 * (i + 0.5) / OCCLUDER_PROBES   # espiral de Fibonacci: pontos bem espalhados na esfera
			var ring := sqrt(1.0 - y * y)
			var angle := i * GOLDEN_ANGLE
			var dir := Vector3(cos(angle) * ring, y, sin(angle) * ring)
			_query.from = center + dir * radius * 1.5
			_query.to = center
			var hit := space.intersect_ray(_query)
			if not hit.is_empty():
				inscribed = minf(inscribed, ((hit["position"] as Vector3) - center).length())
	var sphere := SphereOccluder3D.new()
	sphere.radius = inscribed * OCCLUDER_MARGIN
	var occluder := OccluderInstance3D.new()
	occluder.name = "Occluder"
	occluder.occluder = sphere
	add_child(occluder)


func _prepare_colliders() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).create_trimesh_collision()
		_has_colliders = true
