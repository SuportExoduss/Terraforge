class_name DefenderSystem
extends Node3D
## SYS-006: Defensores. Sentinelas que patrulham o território de cada civilização e só se importam com
## INVASORES (corredor de outra civilização pisando no chão deles). Seis estados: PATRULHA → ALERTA (aviso
## visível) → PERSEGUIÇÃO → ATAQUE (golpe anunciado: olho cresce e vermelhece) → RETORNO → REPOUSO.
## Regras do GDMD: nunca saem do território, nunca atacam o dono, nunca matam de uma vez (1 ponto por golpe,
## com recarga), são mais lentos que o corredor (invasão sempre possível) e o número cresce com o território
## mas tem teto. Fala com o resto só por sinais e pelo grupo "runners" (e Services para território/bases).
## ponytail: corpo = cone + olho (silhueta própria, sem modelo ainda); sem sinal de "golpe" para HUD/som.

enum State { PATROL, ALERT, CHASE, ATTACK, RETURN, REST }

const BODY_HEIGHT := 2.2
const SENSE_INTERVAL := 0.2        # percepção a 5 Hz: barato mesmo com 18 sentinelas
const EYE_IDLE := Color(0.1, 0.1, 0.12)
const EYE_ALERT := Color(1.0, 0.85, 0.2)
const EYE_ATTACK := Color(1.0, 0.1, 0.05)

@export var max_per_civilization := 3
@export var territory_per_defender := 0.06   # +1 sentinela a cada 6% do planeta (além da primeira)
@export var patrol_speed := 3.0
@export var chase_speed := 9.0               # abaixo da velocidade do corredor (12): dá para fugir
@export var detect_radius := 16.0
@export var give_up_radius := 26.0
@export var attack_range := 3.0
@export var alert_seconds := 0.6
@export var windup_seconds := 0.8
@export var attack_cooldown := 2.0
@export var rest_seconds := 2.0
@export var damage := 1


class Guard extends RefCounted:
	var node: Node3D
	var eye: MeshInstance3D
	var eye_material: StandardMaterial3D
	var owner_id := 0
	var state := State.REST
	var position := Vector3.ZERO     # no chão
	var goal := Vector3.ZERO
	var target: PlanetRunner = null
	var clock := 0.0
	var cooldown := 0.0
	var sense := 0.0


var _guards: Array[Guard] = []
var _dead := {}          # civilizações eliminadas: sem sentinelas novas
var _active := false
var _balance_clock := 0.0


func _ready() -> void:
	EventBus.match_started.connect(func() -> void: _active = true; _balance_clock = 0.0)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.civilization_eliminated.connect(_on_eliminated)


func _process(delta: float) -> void:
	if not _active:
		return
	_balance_clock -= delta
	if _balance_clock <= 0.0:
		_balance_clock = 1.0
		_balance()
	for guard in _guards:
		_update(guard, delta)


# O número de sentinelas acompanha o território (mín. 1, teto max_per_civilization), nunca recua no meio da partida.
func _balance() -> void:
	if Services.territory == null:
		return
	var counts := {}
	for guard in _guards:
		counts[guard.owner_id] = counts.get(guard.owner_id, 0) + 1
	for id in Services.home_bases.keys():
		if _dead.has(id):
			continue
		var wanted := clampi(1 + int(Services.territory.owned_fraction(id) / territory_per_defender), 1, max_per_civilization)
		for n in wanted - counts.get(id, 0):
			_spawn(id)


func _spawn(owner_id: int) -> void:
	var guard := Guard.new()
	guard.owner_id = owner_id
	guard.position = _patrol_point(owner_id)
	guard.goal = guard.position
	var color := Color(0.6, 0.6, 0.6)
	if Services.themes != null:
		color = Services.themes.theme_of(owner_id).ground_tint.lightened(0.25)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.9
	cone.height = BODY_HEIGHT
	cone.radial_segments = 8
	cone.material = _flat_material(color)
	var body := MeshInstance3D.new()
	body.mesh = cone
	body.position.y = BODY_HEIGHT * 0.5
	var ball := SphereMesh.new()
	ball.radius = 0.3
	ball.height = 0.6
	guard.eye_material = _flat_material(EYE_IDLE)
	ball.material = guard.eye_material
	guard.eye = MeshInstance3D.new()
	guard.eye.mesh = ball
	guard.eye.position = Vector3(0.0, BODY_HEIGHT * 0.55, 0.75)   # na "frente" (+Z do modelo)
	guard.node = Node3D.new()
	guard.node.name = "Defender%d_%d" % [owner_id, _guards.size()]
	guard.node.add_child(body)
	guard.node.add_child(guard.eye)
	guard.node.add_to_group("defenders")
	add_child(guard.node)
	_place(guard, Vector3.ZERO)
	_guards.append(guard)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


# ---------------------------------------------------------------------------------------------
# Máquina de estados
# ---------------------------------------------------------------------------------------------

func _update(guard: Guard, delta: float) -> void:
	guard.cooldown -= delta
	guard.clock += delta
	match guard.state:
		State.PATROL, State.RETURN, State.REST:
			_look_for_invader(guard, delta)
			if guard.state == State.ALERT:
				return
			_calm(guard, delta)
		State.ALERT:
			if not _still_invader(guard):
				_set_state(guard, State.RETURN)
				return
			_face(guard, guard.target.global_position)
			guard.node.scale = Vector3.ONE * (1.0 + 0.12 * sin(guard.clock * 24.0))   # aviso: treme
			if guard.clock >= alert_seconds:
				_set_state(guard, State.CHASE)
		State.CHASE:
			if not _still_invader(guard):
				_set_state(guard, State.RETURN)
				return
			var target_point := guard.target.global_position
			_step(guard, target_point, chase_speed, delta)
			if guard.cooldown <= 0.0 and guard.position.distance_to(target_point) <= attack_range:
				_set_state(guard, State.ATTACK)
		State.ATTACK:
			if not _still_invader(guard):
				_set_state(guard, State.RETURN)
				return
			_face(guard, guard.target.global_position)
			guard.eye.scale = Vector3.ONE * lerpf(1.0, 2.4, clampf(guard.clock / windup_seconds, 0.0, 1.0))   # golpe anunciado
			if guard.clock >= windup_seconds:
				if guard.position.distance_to(guard.target.global_position) <= attack_range * 1.3:
					var health := guard.target.get_node_or_null("Health") as Health
					if health != null:
						health.take_damage(damage)
				guard.cooldown = attack_cooldown
				_set_state(guard, State.CHASE)


# PATRULHA anda entre pontos do próprio chão; RETORNO volta à base; REPOUSO fica parado um instante.
func _calm(guard: Guard, delta: float) -> void:
	match guard.state:
		State.PATROL:
			if _step(guard, guard.goal, patrol_speed, delta) and guard.position.distance_to(guard.goal) > 1.0:
				return
			guard.goal = _patrol_point(guard.owner_id)
		State.RETURN:
			var base: Dictionary = Services.home_bases.get(guard.owner_id, {})
			var home: Vector3 = base.get("position", guard.position)
			if not _step(guard, home, patrol_speed * 1.5, delta) or guard.position.distance_to(home) < 3.0:
				_set_state(guard, State.REST)
		State.REST:
			if guard.clock >= rest_seconds:
				guard.goal = _patrol_point(guard.owner_id)
				_set_state(guard, State.PATROL)


func _set_state(guard: Guard, state: State) -> void:
	guard.state = state
	guard.clock = 0.0
	guard.node.scale = Vector3.ONE
	guard.eye.scale = Vector3.ONE
	guard.eye_material.albedo_color = EYE_ALERT if state == State.ALERT else (EYE_ATTACK if state == State.ATTACK or state == State.CHASE else EYE_IDLE)


func _look_for_invader(guard: Guard, delta: float) -> void:
	guard.sense -= delta
	if guard.sense > 0.0:
		return
	guard.sense = SENSE_INTERVAL
	var best := detect_radius
	var found: PlanetRunner = null
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		var d := guard.position.distance_to(runner.global_position)
		if d <= best and _is_invader(guard.owner_id, runner):
			best = d
			found = runner
	if found != null:
		guard.target = found
		_set_state(guard, State.ALERT)


# Invasor = corredor ativo de OUTRA civilização, pisando no território desta. O dono nunca é alvo.
func _is_invader(owner_id: int, runner: PlanetRunner) -> bool:
	if runner == null or not is_instance_valid(runner) or not runner.is_active_in_field():
		return false
	if (runner.get_node("Civilization") as Civilization).id == owner_id:
		return false
	return Services.territory.is_owned_by(owner_id, runner.global_position)


func _still_invader(guard: Guard) -> bool:
	return _is_invader(guard.owner_id, guard.target) \
			and guard.position.distance_to(guard.target.global_position) <= give_up_radius


# ---------------------------------------------------------------------------------------------
# Movimento (sempre colado ao chão e DENTRO do território do dono)
# ---------------------------------------------------------------------------------------------

## Anda um passo rumo a `goal`. Devolve false se a borda do território barrou o passo.
func _step(guard: Guard, goal: Vector3, speed: float, delta: float) -> bool:
	var planet := Services.planet
	var up := (guard.position - planet.center).normalized()
	var to := (goal - guard.position).slide(up)
	var distance := to.length()
	if distance < 0.2:
		return true
	var next := guard.position + to / distance * minf(speed * delta, distance)
	var next_up := (next - planet.center).normalized()
	next = planet.center + next_up * planet.get_surface_radius(next_up)
	if not Services.territory.is_owned_by(guard.owner_id, next):
		return false
	guard.position = next
	_place(guard, to)
	return true


func _face(guard: Guard, point: Vector3) -> void:
	var up := (guard.position - Services.planet.center).normalized()
	_place(guard, (point - guard.position).slide(up))


# Posiciona o nó no chão; `facing` = direção tangente (zero = mantém/qualquer).
func _place(guard: Guard, facing: Vector3) -> void:
	var up := (guard.position - Services.planet.center).normalized()
	var front := facing.slide(up)
	if front.length_squared() < 0.0001:
		front = guard.node.global_basis.z.slide(up) if guard.node.is_inside_tree() else Vector3.ZERO
	if front.length_squared() < 0.0001:
		front = up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD)
	guard.node.global_transform = Transform3D(Basis.looking_at(front.normalized(), up, true), guard.position)


# Sorteia um ponto do chão do dono perto da base; sem sorte, a própria base.
func _patrol_point(owner_id: int) -> Vector3:
	var planet := Services.planet
	var base: Dictionary = Services.home_bases.get(owner_id, {})
	var center: Vector3 = base.get("position", planet.center + Vector3.UP * planet.radius)
	var up := (center - planet.center).normalized()
	var tangent := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD).normalized()
	for attempt in 8:
		var offset := tangent.rotated(up, randf() * TAU) * randf_range(3.0, 18.0)
		var direction := (center + offset - planet.center).normalized()
		var point := planet.center + direction * planet.get_surface_radius(direction)
		if Services.territory.is_owned_by(owner_id, point):
			return point
	return center


# ---------------------------------------------------------------------------------------------

func _on_eliminated(owner_id: int) -> void:
	_dead[owner_id] = true
	for i in range(_guards.size() - 1, -1, -1):
		if _guards[i].owner_id == owner_id:
			_guards[i].node.queue_free()
			_guards.remove_at(i)


func _on_match_ended() -> void:
	_active = false
	for guard in _guards:
		guard.node.queue_free()
	_guards.clear()
