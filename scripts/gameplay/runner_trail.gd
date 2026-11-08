class_name RunnerTrail
extends Node
## O rastro do corredor (SYS-001): existe só FORA do território do dono. Sair do domínio inicia a
## gravação; voltar a qualquer parte dele fecha o circuito, anuncia territory_loop_closed e limpa.
## A LISTA `points` é o dado de jogo; a fileira de cercas é só a projeção visual dela.
## Nó filho de um PlanetRunner (precisa do irmão "Civilization").

const MIN_POINTS_FOR_LOOP := 3          # um circuito precisa de ao menos um triângulo
const ANCHOR_CHECK_INTERVAL := 0.25     # vigia da retaguarda (DD-123): barata, não roda todo frame

# A cerca é POSTE + ELO (DD-125): um poste em cada ponto do rastro, um elo esticado entre cada par.
# O elo é um modelo de 1 unidade de comprimento ao longo de +Z, esticado até a distância real dos postes.
@export var post_model: PackedScene
@export var link_model: PackedScene
@export var point_spacing: float = 1.5
@export var surface_offset: float = 0.15            # levanta o rastro do chão (anti z-fighting)
@export var post_rotation_offset_degrees := Vector3.ZERO
@export var post_scale: float = 1.0
@export var link_height: float = 0.16               # altura do elo no poste (unidades do modelo; anda com post_scale)
@export var post_shadow := true
@export_range(0.0, 3.0) var post_shadow_size: float = 1.4        # fração da largura do poste
@export_range(0.0, 1.0) var post_shadow_opacity: float = 0.3
@export var prewarm_segments: int = 64              # quantos postes (e elos) nascem antes do GO
@export var grow_segments: int = 32                 # rastro maior que o estoque: o bolso cresce neste passo (a cerca nunca para)

var points: Array[Vector3] = []

var owner_id: int:
	get:
		return _civilization.id if _civilization != null else 0

var _runner: PlanetRunner
var _civilization: Civilization
var _container: Node3D
var _posts: Array[Node3D] = []
var _links: Array[Node3D] = []
var _active_posts := 0
var _active_links := 0
var _was_inside := true
var _last_inside_position := Vector3.ZERO
var _has_last_inside := false
var _anchor := Vector3.ZERO
var _has_anchor := false
var _anchor_clock := 0.0
var _shadow_mesh: CylinderMesh
var _shadow_material: StandardMaterial3D
var _shadow_offset := Vector3.ZERO


func _ready() -> void:
	_runner = get_parent() as PlanetRunner
	_civilization = get_parent().get_node_or_null("Civilization") as Civilization
	if _runner == null or _civilization == null:
		push_error("[RunnerTrail] %s precisa estar sob um PlanetRunner com crachá Civilization." % name)
		set_process(false)
		return
	Services.register_trail(self)
	# Embarcou no foguete (DD-100) ou foi eliminado (R1): a expansão pendente evapora.
	EventBus.base_fallen.connect(_on_base_fallen)
	EventBus.civilization_eliminated.connect(_on_eliminated)
	if post_model != null or link_model != null:
		_prewarm_segments()


func _exit_tree() -> void:
	Services.unregister_trail(self)


## Corte por adversário (DD-099): a expansão quebra na hora e o fato é anunciado.
func cut(attacker_id: int) -> void:
	if points.is_empty():
		return
	_clear()
	EventBus.trail_cut.emit(owner_id, attacker_id)


func _process(delta: float) -> void:
	# Fora de campo (pré-GO, embarcado, eliminado): nada de gravar pontos no vazio.
	if not _runner.is_active_in_field():
		return
	var planet := Services.planet
	if planet == null or not planet.surface_ready:
		return

	var territory := Services.territory
	var position := _runner.global_position
	var inside: bool = territory != null and territory.is_owned_by(_civilization.id, position)

	if inside:
		if not _was_inside and points.size() >= MIN_POINTS_FOR_LOOP:
			# Cópia: o rastro é limpo em seguida, mas quem recebeu precisa dos pontos intactos.
			EventBus.territory_loop_closed.emit(_civilization.id, PackedVector3Array(points))
		if not points.is_empty():
			_clear()
		_last_inside_position = position
		_has_last_inside = true
	else:
		_record_point_if_far_enough(_foot_point(planet, position))
		_check_anchor(territory, delta)

	_was_inside = inside


# DD-123: a vigia da retaguarda. Se o chão de onde a expedição SAIU for tomado, a conexão morreu:
# a expansão evapora e o corredor é chamado de volta (sem dano — não foi corte).
# A âncora é o último ponto DENTRO do território (o código Unity testava points[0], que por
# construção já está fora — ver nota na migração).
func _check_anchor(territory: Object, delta: float) -> void:
	_anchor_clock += delta
	if _anchor_clock < ANCHOR_CHECK_INTERVAL or points.is_empty():
		return
	_anchor_clock = 0.0
	if territory != null and _has_anchor and not territory.is_owned_by(_civilization.id, _anchor):
		_clear()
		_has_last_inside = false   # a âncora velha morreu; só vale outra depois de voltar para dentro
		EventBus.trail_anchor_lost.emit(_civilization.id)


func _record_point_if_far_enough(surface_point: Vector3) -> void:
	if not points.is_empty() and points[-1].distance_to(surface_point) < point_spacing:
		return
	var from := surface_point   # 1º ponto: sem ponto anterior, o poste segue a direção do corredor
	if points.is_empty():
		_anchor = _last_inside_position
		_has_anchor = _has_last_inside
	else:
		from = points[-1]
	points.append(surface_point)
	_place_post(surface_point, surface_point - from)
	if from != surface_point:
		_place_link(from, surface_point)


# O rastro deita no TERRENO real (vales e morros), como os pés.
func _foot_point(planet: Planet, from: Vector3) -> Vector3:
	var up := (from - planet.center).normalized()
	return planet.center + up * (planet.get_surface_radius(up) + surface_offset)


func _up_at(point: Vector3) -> Vector3:
	return (point - Services.planet.center).normalized()


# Planta um poste no ponto, em pé na superfície e virado para a direção da corrida.
# Reciclado de um bolso (só cresce se o rastro passar do estoque).
func _place_post(at: Vector3, direction: Vector3) -> void:
	if _active_posts >= _posts.size():
		if post_model == null:
			return
		_add_segments(grow_segments)
	var post := _posts[_active_posts]
	_active_posts += 1

	var up := _up_at(at)
	var forward := direction.slide(up)
	if forward.length_squared() < 0.001:
		forward = _runner.global_transform.basis.z
	var basis := Basis.looking_at(forward.normalized(), up, true) \
			* Basis.from_euler(post_rotation_offset_degrees * (PI / 180.0))
	post.global_transform = Transform3D(basis.scaled(Vector3.ONE * post_scale), at)
	post.visible = true


# Estica um elo entre o alto de dois postes vizinhos: as pontas caem sempre DENTRO dos postes,
# então a cerca fecha em retas e em curvas, seja qual for a distância real entre eles.
func _place_link(from: Vector3, to: Vector3) -> void:
	if _active_links >= _links.size():
		if link_model == null:
			return
		_add_segments(grow_segments)
	var lift := link_height * post_scale
	var a := from + _up_at(from) * lift
	var b := to + _up_at(to) * lift
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var middle := (a + b) * 0.5
	var link := _links[_active_links]
	_active_links += 1
	var basis := Basis.looking_at((b - a) / length, _up_at(middle), true) \
			* Basis.from_scale(Vector3(1.0, 1.0, length))   # à direita: estica o eixo LOCAL +Z
	link.global_transform = Transform3D(basis, middle)
	link.visible = true


# O estoque inicial nasce antes do GO: incursões normais não instanciam nada. Só um rastro MUITO longo
# (mais que prewarm_segments postes) cresce o bolso em lotes pequenos — melhor um engasgo mínimo que a cerca sumir.
func _prewarm_segments() -> void:
	# top_level: as cercas vivem no mundo, não andam junto com o corredor.
	_container = Node3D.new()
	_container.name = "TrailSegments_%s" % get_parent().name
	_container.top_level = true
	add_child(_container)
	_add_segments(prewarm_segments)


func _add_segments(count: int) -> void:
	for i in count:
		if post_model != null:
			var post := post_model.instantiate() as Node3D
			_container.add_child(post)
			if post_shadow:
				if _shadow_mesh == null:
					_build_shadow_resources(post)
				_attach_shadow(post)
			post.visible = false
			_posts.append(post)
		if link_model != null:
			var link := link_model.instantiate() as Node3D
			_container.add_child(link)
			link.visible = false
			_links.append(link)


# A sombrinha é medida pelo PRÓPRIO modelo: tamanho pela largura real, posição pelo centro da base.
func _build_shadow_resources(post: Node3D) -> void:
	var box := ModelUtils.local_aabb(post)
	if box.size == Vector3.ZERO:
		post_shadow = false
		return
	var diameter := maxf(0.01, maxf(box.size.x, box.size.z) * post_shadow_size)
	_shadow_mesh = CylinderMesh.new()
	_shadow_mesh.top_radius = diameter * 0.5
	_shadow_mesh.bottom_radius = diameter * 0.5
	_shadow_mesh.height = 0.005
	_shadow_mesh.radial_segments = 16
	_shadow_mesh.rings = 1
	_shadow_offset = Vector3(box.get_center().x, box.position.y + 0.02, box.get_center().z)
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.albedo_color = Color(0.0, 0.0, 0.0, post_shadow_opacity)


func _attach_shadow(post: Node3D) -> void:
	if not post_shadow:
		return
	var shadow := MeshInstance3D.new()
	shadow.name = "Sombra"
	shadow.mesh = _shadow_mesh
	shadow.material_override = _shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = _shadow_offset
	post.add_child(shadow)


func _clear() -> void:
	points.clear()
	_has_anchor = false
	# Postes e elos voltam para o bolso (reciclados para o próximo rastro).
	for i in _active_posts:
		_posts[i].visible = false
	for i in _active_links:
		_links[i].visible = false
	_active_posts = 0
	_active_links = 0


func _on_base_fallen(owned_by: int, _conqueror_id: int) -> void:
	if owned_by == owner_id and not points.is_empty():
		_clear()


func _on_eliminated(eliminated_id: int) -> void:
	if eliminated_id == owner_id:
		_clear()
		Services.unregister_trail(self)
		set_process(false)
