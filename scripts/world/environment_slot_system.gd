class_name EnvironmentSlotSystem
extends Node3D
## Slots ambientais (DD-110 / DD-114): o planeta só REVELA. Os slots são posições invisíveis e FIXAS
## (sorteadas pela semente: direção, giro, variação de tamanho, categoria E01-E12 e um "dado de
## densidade"); nunca nascem, somem ou mudam de lugar na partida. A cada quadro o sistema confere
## alguns slots: quem é o dono do chão ali? O que o tema dele põe nesse slot? (DD-117: cresce em
## ~0,9 s.) Slot sem modelo no tema = nada. Dono eliminado (DD-122) = gêmeo morto, ou, se o tema não
## tem gêmeo, o modelo vivo escurecido.
## Pooling = MULTIMESH: um por (civilização, categoria, vivo/morto), com uma vaga por slot da categoria;
## "esconder" é zerar a escala da vaga. Nada de colisão. Este nó precisa ficar na origem (sem giro).

const SLOT_COUNT := 720
const CHECKS_PER_FRAME := 12             # o planeta inteiro é reconferido em ~1 s
const MIN_SLOT_DISTANCE := 5.0
const GROW_SECONDS := 0.9
const DEAD_TINT := Color(0.38, 0.36, 0.34)
# Por categoria E01..E12 (iguais ao EnvironmentSlotSystem do Unity): peso do sorteio e altura padrão.
const WEIGHTS: Array[float] = [0.20, 0.24, 0.18, 0.05, 0.10, 0.05, 0.05, 0.03, 0.03, 0.03, 0.03, 0.01]
const HEIGHTS: Array[float] = [4.0, 2.2, 1.1, 4.5, 1.2, 1.6, 3.5, 6.5, 1.4, 2.0, 1.5, 11.0]
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

@export var slot_seed: int = 20260705   # a semente da partida (multiplayer: vem do servidor)


# Um pedaço (MeshInstance3D) do modelo, como multimesh. `base` leva a malha ao referencial do slot
# (pé do modelo na origem, centrado em X/Z).
class SlotPart:
	var multimesh: MultiMesh
	var base: Transform3D


class SlotGroup:
	var parts: Array[SlotPart] = []
	var model_height := 1.0


var _dirs := PackedVector3Array()
var _yaw := PackedFloat32Array()
var _jitter := PackedFloat32Array()
var _roll := PackedFloat32Array()
var _category := PackedInt32Array()
var _ordinal := PackedInt32Array()       # vaga do slot dentro do multimesh da categoria dele
var _category_size := PackedInt32Array()
var _base_radius := PackedFloat32Array() # raio do terreno SEM a camada do bioma (0 = ainda não medido)
var _key := PackedInt32Array()           # grupo em que o slot está hoje (-1 = vazio)
var _age := PackedFloat32Array()
var _growing: Array[int] = []
var _groups := {}                        # chave -> SlotGroup (ou null: tema sem modelo ali)
var _dead := {}                          # id da civilização eliminada -> true
var _cursor := 0


func _ready() -> void:
	var planet := Services.planet
	if planet == null:
		push_error("[EnvironmentSlotSystem] sem planeta (ponha este nó depois do Planet).")
		set_process(false)
		return
	_generate(planet.radius)
	EventBus.civilization_eliminated.connect(func(id: int) -> void: _dead[id] = true)


## Quantos slots de `owner_id` estão revelados (vivos ou mortos). Para testes e HUD de depuração.
func revealed_count(owner_id: int, dead: bool) -> int:
	var n := 0
	for k in _key:
		if k >= 0 and k / 24 == owner_id and (k % 2 == 1) == dead:
			n += 1
	return n


func _process(delta: float) -> void:
	var planet := Services.planet
	var map := Services.territory
	if planet == null or not planet.surface_ready or Services.themes == null \
			or map == null or not map.has_method("get_owner_at"):
		return
	for i in CHECKS_PER_FRAME:
		_refresh(_cursor, planet, map)
		_cursor = (_cursor + 1) % _dirs.size()
	_grow(delta, planet)


func _generate(radius: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = slot_seed
	var min_dot := cos(MIN_SLOT_DISTANCE / radius)
	_category_size.resize(WEIGHTS.size())
	_category_size.fill(0)
	for n in SLOT_COUNT:
		var dir := Vector3.ZERO
		for attempt in 40:
			dir = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			if not _too_close(dir, min_dot):
				break
		var pick := rng.randf()
		var cat := 0
		while cat < WEIGHTS.size() - 1 and pick > WEIGHTS[cat]:
			pick -= WEIGHTS[cat]
			cat += 1
		_dirs.append(dir)
		_category.append(cat)
		_ordinal.append(_category_size[cat])
		_category_size[cat] += 1
		_roll.append(rng.randf())
		_yaw.append(rng.randf_range(0.0, TAU))
		_jitter.append(rng.randf_range(0.85, 1.2))
	_base_radius.resize(_dirs.size())
	_base_radius.fill(0.0)
	_key.resize(_dirs.size())
	_key.fill(-1)
	_age.resize(_dirs.size())
	_age.fill(0.0)


func _too_close(dir: Vector3, min_dot: float) -> bool:
	for d in _dirs:
		if d.dot(dir) > min_dot:
			return true
	return false


func _refresh(i: int, planet: Planet, map: Object) -> void:
	var owner_id: int = map.get_owner_at(planet.center + _dirs[i] * planet.radius)
	var key := _wanted_key(i, owner_id)
	if key == _key[i]:
		if key >= 0 and _age[i] >= GROW_SECONDS:
			_put(i, planet, 1.0)   # o bioma pode ter terminado de subir depois da revelação
		return
	_hide(i)
	if key < 0:
		return
	_key[i] = key
	_age[i] = 0.0
	if _base_radius[i] == 0.0:
		var elevation: float = planet.painter.get_elevation_at(_dirs[i]) if planet.painter != null else 0.0
		_base_radius[i] = planet.get_surface_radius(_dirs[i]) - elevation
	if not _growing.has(i):
		_growing.append(i)


# Chave do grupo que este slot deve mostrar para este dono (-1 = nada). Chave = (dono * 12 + categoria) * 2 + morto.
func _wanted_key(i: int, owner_id: int) -> int:
	if owner_id == 0:
		return -1
	var theme := Services.themes.theme_of(owner_id)
	if theme == null or _roll[i] > theme.density_of(_category[i]):
		return -1
	var dead := _dead.has(owner_id)
	var key := (owner_id * PlanetTheme.SLOT_COUNT + _category[i]) * 2 + (1 if dead else 0)
	if not _groups.has(key):
		_groups[key] = _build_group(theme, _category[i], dead)
	return key if _groups[key] != null else -1


func _hide(i: int) -> void:
	var k := _key[i]
	if k < 0:
		return
	for part: SlotPart in (_groups[k] as SlotGroup).parts:
		part.multimesh.set_instance_transform(_ordinal[i], HIDDEN)
	_key[i] = -1


func _grow(delta: float, planet: Planet) -> void:
	for n in range(_growing.size() - 1, -1, -1):
		var i := _growing[n]
		if _key[i] < 0:
			_growing.remove_at(n)
			continue
		_age[i] += delta
		_put(i, planet, _age[i] / GROW_SECONDS)
		if _age[i] >= GROW_SECONDS:
			_growing.remove_at(n)


# Põe o slot no chão (terreno + camada do bioma, DD-121), em pé, girado, com `grow` de 0 a 1 (DD-117).
func _put(i: int, planet: Planet, grow: float) -> void:
	var group := _groups[_key[i]] as SlotGroup
	var up := _dirs[i]
	var elevation: float = planet.painter.get_elevation_at(up) if planet.painter != null else 0.0
	var scale_now := HEIGHTS[_category[i]] / group.model_height * _jitter[i] * smoothstep(0.0, 1.0, grow)
	var basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, _yaw[i]) * Basis.from_scale(Vector3.ONE * scale_now)
	var xf := Transform3D(basis, planet.center + up * (_base_radius[i] + elevation))
	for part: SlotPart in group.parts:
		part.multimesh.set_instance_transform(_ordinal[i], xf * part.base)


# Monta os multimeshes de (tema, categoria, vivo/morto). null = tema sem modelo nesse slot.
func _build_group(theme: PlanetTheme, category: int, dead: bool) -> SlotGroup:
	var scene := theme.slot_model(category, dead)
	var darken := false
	if scene == null and dead:
		scene = theme.slot_model(category, false)   # regra do vazio: vivo escurecido
		darken = true
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	var offsets: Array[Transform3D] = []
	var box := AABB()
	for n in meshes.size():
		var xf := Transform3D.IDENTITY
		var up_node: Node = meshes[n]
		while up_node is Node3D:
			xf = (up_node as Node3D).transform * xf
			up_node = up_node.get_parent()
		offsets.append(xf)
		var part_box := xf * meshes[n].mesh.get_aabb()
		box = part_box if n == 0 else box.merge(part_box)
	var group := SlotGroup.new()
	if meshes.is_empty() or box.size.y <= 0.0:
		push_warning("[EnvironmentSlotSystem] slot sem malha utilizável: %s" % scene.resource_path)
		root.free()
		return null
	group.model_height = box.size.y
	var foot := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for n in meshes.size():
		var part := SlotPart.new()
		part.base = Transform3D(Basis.IDENTITY, foot) * offsets[n]
		part.multimesh = MultiMesh.new()
		part.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		part.multimesh.mesh = _darkened(meshes[n].mesh) if darken else meshes[n].mesh
		part.multimesh.instance_count = _category_size[category]
		for k in part.multimesh.instance_count:
			part.multimesh.set_instance_transform(k, HIDDEN)
		var holder := MultiMeshInstance3D.new()
		holder.multimesh = part.multimesh
		add_child(holder)
		group.parts.append(part)
	root.free()
	return group


# O mesmo mesh com a cor dos materiais multiplicada por DEAD_TINT (cópia: o original fica intacto).
func _darkened(mesh: Mesh) -> Mesh:
	var copy := mesh.duplicate() as Mesh
	for s in copy.get_surface_count():
		var material := copy.surface_get_material(s) as BaseMaterial3D
		if material != null:
			var dark := material.duplicate() as BaseMaterial3D
			dark.albedo_color *= DEAD_TINT
			copy.surface_set_material(s, dark)
	return copy
