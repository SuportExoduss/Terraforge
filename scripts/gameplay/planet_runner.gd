class_name PlanetRunner
extends Node3D
## Movimento contínuo sobre a superfície do planeta (o jogador nunca para de correr). A direção vem
## do nó filho "Steering" (teclado/toque do jogador ou cérebro de bot); a gravidade aponta sempre
## para o centro. Convenção: +Z do corredor = frente (o GLB do cowboy olha para +X: _fit_model o gira); a origem do
## nó é o CENTRO do corpo, os pés ficam height_offset abaixo.

@export var move_speed: float = 12.0
@export var turn_speed_degrees: float = 180.0
@export var height_offset: float = 1.0
@export var model_height: float = 2.0

var forward := Vector3.FORWARD
var speed_multiplier := 1.0   # SYS-005: bônus de velocidade (BonusSystem)
var freeze_multiplier := 1.0  # SYS-005: Congelamento do adversário (BonusSystem); multiplica a velocidade
var slow_multiplier := 1.0    # SYS-004: lentidão vinda de eventos (zona 2 do Furacão); quem aplica renova a cada quadro
var push := Vector3.ZERO      # SYS-004: velocidade EXTRA vinda de fora (onda do Tsunami); quem empurra renova, ela decai sozinha
const PUSH_DECAY := 60.0      # unidades/s² (30 u/s some em 0,5 s)
var _steering: Node
var _civilization: Civilization
var _model: Node3D
var _match_started := false
var _aboard_ship := false
var _eliminated := false
var _enabled := true
var _placed := false
var _recalling := false   # DD-123: voltando ao domo sozinho (sem rastro, sem dano)


## O corredor está de fato em campo? (Partida rolando, não embarcado, não eliminado, não em recall:
## o rastro não grava e não pode ser cortado enquanto ele volta.)
func is_active_in_field() -> bool:
	return _enabled and _match_started and not _aboard_ship and not _eliminated and not _recalling


## Troca o motorista em campo (o servidor entrega o corredor a um jogador remoto). O antigo é descartado.
func use_steering(driver: Node) -> void:
	if _steering != null:
		_steering.name = "Steering_old"
		_steering.queue_free()
	driver.name = "Steering"
	add_child(driver)
	_steering = driver


func _ready() -> void:
	_steering = get_node_or_null("Steering")
	if _steering == null:
		push_error("[PlanetRunner] %s não tem um motorista (filho 'Steering')." % name)
	_civilization = get_node_or_null("Civilization") as Civilization
	add_to_group("runners")
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
	EventBus.trail_anchor_lost.connect(_on_anchor_lost)


func _process(delta: float) -> void:
	var planet := Services.planet
	if planet == null or not planet.surface_ready or not _enabled:
		return
	if not _placed:
		_place_on_surface(planet)
	if not _match_started or _aboard_ship:
		return

	var up := (global_position - planet.center).normalized()
	var steer: float = _recall_steer(up, delta) if _recalling else (_steering.get_steer() if _steering != null else 0.0)
	var speed := move_speed * speed_multiplier * freeze_multiplier * slow_multiplier
	var moved := RunnerMotion.advance(global_position, forward, steer, delta, planet, height_offset, speed, turn_speed_degrees, push)
	push = push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)
	forward = moved[1]

	# Pés para o centro, olhar para a frente.
	var next: Vector3 = moved[0]
	global_transform = Transform3D(Basis.looking_at(forward, (next - planet.center).normalized(), true), next)


# DD-123: no recall o volante aponta para o domo. Termina ao pisar de novo no próprio território
# (ou se a base sumiu): aí o controle volta ao motorista. Devolve o giro (-1..1) deste quadro.
func _recall_steer(up: Vector3, delta: float) -> float:
	var base: Dictionary = Services.home_bases.get(_civilization.id, {})
	var territory := Services.territory
	if base.is_empty() or territory == null or territory.is_owned_by(_civilization.id, global_position):
		_recalling = false
		return 0.0
	var to_base: Vector3 = ((base["position"] as Vector3) - global_position).slide(up)
	return clampf(-forward.signed_angle_to(to_base, up) / (deg_to_rad(turn_speed_degrees) * delta), -1.0, 1.0)


## Leva o corredor a outro ponto da superfície (volta à base, nave pousada) mantendo a direção
## tangente; se a direção antiga ficar de pé no novo ponto, escolhe outra.
func teleport_to(point: Vector3) -> void:
	push = Vector3.ZERO
	var planet := Services.planet
	var up := (point - planet.center).normalized()
	var tangent := forward.slide(up)
	if tangent.length_squared() < 0.01:
		tangent = Vector3.BACK.slide(up) if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT.slide(up)
	forward = tangent.normalized()
	var pos: Vector3 = planet.center + up * (planet.get_surface_radius(up) + height_offset)
	global_transform = Transform3D(Basis.looking_at(forward, up, true), pos)


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
	# MEDIDO (tools/inspect_runner.gd): o CowboyRunner.glb olha para +X (dedos, ombros e inclinação da cabeça);
	# o corredor anda para +Z. Girar +X até +Z = -90° em Y. Depois recentra X/Z pelo centro já girado.
	_model.rotation.y = -PI / 2.0
	var center := _model.basis * box.get_center()
	_model.position = Vector3(-center.x, -height_offset - box.position.y * s, -center.z)


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


# DD-123: o chão de onde a expedição saiu foi tomado: o rastro já evaporou (RunnerTrail), o corredor volta.
func _on_anchor_lost(owner_id: int) -> void:
	if _is_me(owner_id) and is_active_in_field():
		_recalling = true


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
