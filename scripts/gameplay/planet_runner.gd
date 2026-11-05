class_name PlanetRunner
extends Node3D
## Movimento contínuo sobre a superfície do planeta (o jogador nunca para de correr). A direção vem
## do nó filho "Steering" (teclado/toque do jogador ou cérebro de bot); a gravidade aponta sempre
## para o centro. Convenção: +Z do corredor = frente (os GLBs do Tripo olham para +Z); a origem do
## nó é o CENTRO do corpo, os pés ficam height_offset abaixo.

@export var move_speed: float = 12.0
@export var turn_speed_degrees: float = 180.0
@export var height_offset: float = 1.0
@export var model_height: float = 2.0

var forward := Vector3.FORWARD
var _steering: Node
var _civilization: Civilization
var _model: Node3D
var _match_started := false
var _aboard_ship := false
var _eliminated := false
var _enabled := true
var _placed := false


## O corredor está de fato em campo? (Partida rolando, não embarcado, não eliminado.)
func is_active_in_field() -> bool:
	return _enabled and _match_started and not _aboard_ship and not _eliminated


func _ready() -> void:
	_steering = get_node_or_null("Steering")
	if _steering == null:
		push_error("[PlanetRunner] %s não tem um motorista (filho 'Steering')." % name)
	_civilization = get_node_or_null("Civilization") as Civilization
	_model = get_node_or_null("Model") as Node3D
	_fit_model()
	_start_animation()
	# DD-096: o personagem só aparece e corre no GO! da abertura.
	_set_visible(false)

	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.base_fallen.connect(_on_base_fallen)
	EventBus.base_relocated.connect(_on_base_relocated)
	EventBus.civilization_eliminated.connect(_on_eliminated)


func _process(delta: float) -> void:
	var planet := Services.planet
	if planet == null or not planet.surface_ready or not _enabled:
		return
	if not _placed:
		_place_on_surface(planet)
	if not _match_started or _aboard_ship:
		return

	var steer: float = _steering.get_steer() if _steering != null else 0.0

	# 1. Gira a direção ao redor do "up" local (o volante). Direita = sentido negativo (Godot é destro).
	var up := (global_position - planet.center).normalized()
	forward = forward.rotated(up, -steer * deg_to_rad(turn_speed_degrees) * delta)

	# 2. Avança sempre.
	var next := global_position + forward * (move_speed * delta)

	# 3. Recola na superfície REAL (vale ou morro), nunca na esfera matemática.
	var next_up := (next - planet.center).normalized()
	next = planet.center + next_up * (planet.get_surface_radius(next_up) + height_offset)

	# 4. A direção precisa continuar tangente (senão acumula erro por frame).
	forward = (forward - next_up * forward.dot(next_up)).normalized()

	# 5. Pés para o centro, olhar para a frente.
	global_transform = Transform3D(Basis.looking_at(forward, next_up, true), next)


# Cola o personagem na superfície e escolhe uma direção inicial tangente a ela. O eixo de referência
# troca se o spawn cair alinhado a ele. Postura aplicada JÁ no nascimento (câmera enquadra sem solavanco).
func _place_on_surface(planet: Planet) -> void:
	_placed = true
	var up := (global_position - planet.center).normalized()
	var reference := Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT
	forward = (reference - up * reference.dot(up)).normalized()
	var pos: Vector3 = planet.center + up * (planet.get_surface_radius(up) + height_offset)
	global_transform = Transform3D(Basis.looking_at(forward, up, true), pos)


# Ajusta o GLB para model_height de altura, pés em -height_offset e centrado em X/Z.
func _fit_model() -> void:
	if _model == null:
		return
	var box := ModelUtils.local_aabb(_model)
	if box.size.y <= 0.0:
		return
	var s := model_height / box.size.y
	_model.scale = Vector3.ONE * s
	# O glTF importado olha para -Z; o corredor anda para +Z: gira 180° (o centro X/Z também inverte).
	_model.rotation.y = PI
	var center_xz := box.get_center() * s
	_model.position = Vector3(center_xz.x, -height_offset - box.position.y * s, center_xz.z)


func _start_animation() -> void:
	if _model == null:
		return
	for node in _model.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		var names := player.get_animation_list()
		if names.is_empty():
			continue
		player.get_animation(names[0]).loop_mode = Animation.LOOP_LINEAR
		player.play(names[0])
		return


func _set_visible(visible_now: bool) -> void:
	if _model != null:
		_model.visible = visible_now


func _is_me(owner_id: int) -> bool:
	return _civilization != null and owner_id == _civilization.id


func _on_match_started() -> void:
	_match_started = true
	_set_visible(true)


func _on_match_ended() -> void:
	_enabled = false


# DD-100: base dominada = embarque IMEDIATO (some do campo até a nave pousar).
func _on_base_fallen(owner_id: int, _conqueror_id: int) -> void:
	if _is_me(owner_id):
		_aboard_ship = true
		_set_visible(false)


# Nave pousou e a contagem zerou: desembarca. Eliminado não desembarca.
func _on_base_relocated(owner_id: int, _new_position: Vector3) -> void:
	if not _is_me(owner_id) or _eliminated:
		return
	_aboard_ship = false
	if _match_started:
		_set_visible(true)


# R1: eliminado = fora do campo para sempre (o nó permanece para manter os registros da rodada).
func _on_eliminated(owner_id: int) -> void:
	if _is_me(owner_id):
		_eliminated = true
		_enabled = false
		_set_visible(false)
