class_name AcidRainEvent
extends GlobalEvent
## SYS-004 / DD-107: a CHUVA ÁCIDA. AVISO: nuvens verdes crescem sobre uma área e o chão embaixo esverdeia (a contagem
## corre) → EXECUÇÃO: a área anda devagar pelo planeta e chove; quem está nela perde 1 pt/s, mas DENTRO DO PRÓPRIO
## TERRITÓRIO só 50% (a vantagem de defender sua área) → CICATRIZ: plantas queimadas e solo ressecado (DD-108) e flores
## raras = bônus (DD-106). Nunca mexe no território (DD-024).
## ponytail: a área é um círculo no chão (raio em u) e o "céu verde" são 7 nuvens achatadas com uma mancha verde plana
## embaixo de cada uma; chuva = 28 riscos que caem em laço. Troque por domo/shader/partículas se incomodar.

const EVENT_NAME := "CHUVA ÁCIDA SE APROXIMANDO"
const CLOUDS := 7          # 1 no centro + 6 em anel
const DROPS := 28
const BURNED := 14
const FLOWERS := 5
const SKY_TINT := Color(0.3, 0.55, 0.2, 0.35)
const BURNT_TINT := Color(0.22, 0.17, 0.1, 0.85)
const BURNED_SCALE := Vector3(1.2, 2.4, 1.2)
const FLOWER_SCALE := Vector3(1.4, 1.4, 1.4)
const PATCH_DIAMETER := 22.0
const CLOUD_SIZE := Vector3(30.0, 5.0, 30.0)

@export var rain_seconds := 16.0
@export var rain_radius := 45.0         # u pelo chão (raio da área)
@export var drift_speed := 4.0          # u/s pelo chão
@export var cloud_height := 20.0
@export var damage_per_second := 1.0
@export var own_territory_factor := 0.5   # Adendo 02: 50% do dano no próprio território

var center_dir := Vector3.UP
var _heading := Vector3.RIGHT
var _clouds: Array[MeshInstance3D] = []
var _patches: Array[MeshInstance3D] = []
var _cloud_angle: Array[float] = []
var _cloud_ring: Array[float] = []      # 0..1 do raio
var _drops: Array[MeshInstance3D] = []
var _drop_angle: Array[float] = []
var _drop_ring: Array[float] = []
var _drop_phase: Array[float] = []
var _burned: Array[MeshInstance3D] = []
var _flowers: Array[MeshInstance3D] = []
var _burn := {}                          # id do corredor -> dano acumulado (1.0 = 1 ponto)


func _event_name() -> String:
	return EVENT_NAME


func _active_seconds() -> float:
	return rain_seconds


func _setup() -> void:
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 0.5
	cloud_mesh.height = 1.0
	cloud_mesh.radial_segments = 16
	cloud_mesh.rings = 8
	cloud_mesh.material = _glass(Color(0.34, 0.5, 0.26, 0.8))
	for i in CLOUDS:
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud%d" % i
		cloud.mesh = cloud_mesh
		cloud.visible = false
		add_child(cloud)
		_clouds.append(cloud)
		var patch := make_disc("Patch%d" % i, SKY_TINT)
		_material(patch).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_patches.append(patch)
		_cloud_angle.append(TAU * (i - 1) / 6.0)
		_cloud_ring.append(0.0 if i == 0 else 0.6)
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.12, 3.0, 0.12)
	drop_mesh.material = _glass(Color(0.6, 0.95, 0.4, 0.7))
	for i in DROPS:
		var drop := MeshInstance3D.new()
		drop.name = "Drop%d" % i
		drop.mesh = drop_mesh
		drop.visible = false
		add_child(drop)
		_drops.append(drop)
		_drop_angle.append(randf() * TAU)
		_drop_ring.append(sqrt(randf()))
		_drop_phase.append(randf())
	var plant_mesh := CylinderMesh.new()
	plant_mesh.top_radius = 0.0
	plant_mesh.bottom_radius = 0.5
	plant_mesh.height = 1.0
	plant_mesh.radial_segments = 6
	plant_mesh.rings = 1
	plant_mesh.material = _unshaded(Color(0.12, 0.09, 0.06))
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.5
	flower_mesh.height = 1.0
	flower_mesh.radial_segments = 8
	flower_mesh.rings = 4
	flower_mesh.material = _unshaded(Color(0.95, 0.4, 0.75))
	_pool("Burned", plant_mesh, BURNED, _burned)
	_pool("Flower", flower_mesh, FLOWERS, _flowers)


func _begin_warning() -> bool:
	var start := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()   # uniforme na esfera
	plan(start, start.cross(Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))))
	print("[World] CHUVA ÁCIDA se aproximando! (DD-107)")
	return true


## Fixa o centro da área e a direção em que ela anda (também usada pelos testes).
func plan(start: Vector3, heading: Vector3) -> void:
	center_dir = start.normalized()
	_heading = heading.slide(center_dir).normalized()
	_burn.clear()
	_hide()
	for patch in _patches:
		_material(patch).albedo_color = SKY_TINT
	_place_sky(0.15)


func _tick_warning(remaining: float, _delta: float) -> void:
	_place_sky(lerpf(0.15, 1.0, clampf(1.0 - remaining / warning_seconds, 0.0, 1.0)))   # as nuvens crescem


func _begin_active() -> void:
	for drop in _drops:
		drop.visible = true


func _tick_active(delta: float) -> bool:
	var axis := center_dir.cross(_heading)   # a área anda em círculo máximo
	var angle := drift_speed * delta / Services.planet.radius
	center_dir = center_dir.rotated(axis, angle)
	_heading = _heading.rotated(axis, angle)
	_place_sky(1.0)
	_place_drops()
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		if runner.is_active_in_field():
			_burn_runner(runner, delta)
	return clock >= rain_seconds


func _begin_scar() -> void:
	for cloud in _clouds:
		cloud.visible = false
	for drop in _drops:
		drop.visible = false
	for patch in _patches:
		_material(patch).albedo_color = BURNT_TINT   # o chão sob a chuva fica ressecado
	var b := ground_basis(center_dir)
	for plant in _burned:
		_scatter(plant, b, 1.0, BURNED_SCALE)
	for flower in _flowers:
		_scatter(flower, b, 0.6, FLOWER_SCALE)
	EventBus.bonus_drop_requested.emit(ground_point(center_dir), randi_range(3, 4))   # flores raras
	print("[World] A chuva ácida passou: plantas queimadas e flores raras (DD-108).")


func _tick_scar(life: float) -> void:
	for patch in _patches:
		patch.scale = Vector3(PATCH_DIAMETER * life, 0.12, PATCH_DIAMETER * life)
	for plant in _burned:
		plant.scale = BURNED_SCALE * life
	for flower in _flowers:
		flower.scale = FLOWER_SCALE * life


func _hide() -> void:
	for node in _clouds + _patches + _drops + _burned + _flowers:
		node.visible = false


## Dano por segundo que a chuva dá a `runner` agora: 0 fora da área, cheio exposto, metade no próprio território.
func rate_for(runner: PlanetRunner) -> float:
	var planet := Services.planet
	var unit := (runner.global_position - planet.center).normalized()
	if acos(clampf(unit.dot(center_dir), -1.0, 1.0)) * planet.radius > rain_radius:
		return 0.0
	var civilization := runner.get_node_or_null("Civilization") as Civilization
	if civilization != null and Services.territory != null and Services.territory.is_owned_by(civilization.id, runner.global_position):
		return damage_per_second * own_territory_factor
	return damage_per_second


func _burn_runner(runner: PlanetRunner, delta: float) -> void:
	var id := runner.get_instance_id()
	var rate := rate_for(runner)
	if rate <= 0.0:
		_burn[id] = 0.0
		return
	_burn[id] = _burn.get(id, 0.0) + rate * delta
	if _burn[id] >= 1.0:
		_burn[id] -= 1.0
		var health := runner.get_node_or_null("Health") as Health
		if health != null:
			health.take_damage(1, "CHUVA ÁCIDA")


# Direção (do centro do planeta) de um ponto da área: ângulo + fração do raio, a partir do centro atual.
func _dir_at(b: Basis, angle: float, ring: float) -> Vector3:
	var offset := (b.x * cos(angle) + b.z * sin(angle)) * ring * rain_radius
	return (center_dir + offset / Services.planet.radius).normalized()


func _place_sky(grow: float) -> void:
	var b := ground_basis(center_dir)
	for i in CLOUDS:
		var direction := _dir_at(b, _cloud_angle[i], _cloud_ring[i])
		place_disc(_patches[i], direction, PATCH_DIAMETER * grow)
		_clouds[i].global_transform = Transform3D(ground_basis(direction), ground_point(direction) + direction * cloud_height)
		_clouds[i].scale = CLOUD_SIZE * grow
		_clouds[i].visible = true


func _place_drops() -> void:
	var b := ground_basis(center_dir)
	for i in DROPS:
		var direction := _dir_at(b, _drop_angle[i], _drop_ring[i])
		var fall := fposmod(_drop_phase[i] + clock * 1.3, 1.0)
		_drops[i].global_transform = Transform3D(ground_basis(direction), ground_point(direction) + direction * lerpf(cloud_height, 0.5, fall))


# Espalha `node` num ponto qualquer da área (centro `b`), de pé no chão com giro aleatório.
func _scatter(node: MeshInstance3D, b: Basis, lift: float, node_scale: Vector3) -> void:
	var direction := _dir_at(b, randf() * TAU, sqrt(randf()) * 0.9)
	node.global_transform = Transform3D(ground_basis(direction).rotated(direction, randf() * TAU), ground_point(direction) + direction * lift)
	node.scale = node_scale
	node.visible = true


func _pool(prefix: String, mesh: Mesh, count: int, into: Array[MeshInstance3D]) -> void:
	for i in count:
		var piece := MeshInstance3D.new()
		piece.name = "%s%d" % [prefix, i]
		piece.mesh = mesh
		piece.visible = false
		add_child(piece)
		into.append(piece)


func _glass(color: Color) -> StandardMaterial3D:
	var material := _unshaded(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _material(disc: MeshInstance3D) -> StandardMaterial3D:
	return (disc.mesh as PrimitiveMesh).material as StandardMaterial3D


func _focus_direction() -> Vector3:
	return center_dir


func _focus_heading() -> Vector3:
	return _heading
