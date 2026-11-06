class_name BonusSystem
extends Node3D
## SYS-005: bônus no chão. Um evento global avisa (bonus_drop_requested) e os cristais nascem ao redor do
## ponto, parados e girando, até alguém encostar (ou 40 s se passarem). Cada cristal ativa NA HORA ao ser
## pego (GDMD: "alguns são ativados automaticamente"). Bots e jogador pegam igual: o primeiro corredor em
## campo dentro do raio leva. Fala com o resto só por sinais (bonus_activated) e pelo grupo "runners".
## Os 5 tipos: Velocidade, Recuperação, Vida Extra, Congelamento (adversários por perto andam mais devagar) e
## Escudo Temporal (sem dano de pontos; o corte do rastro continua valendo).
## ponytail: cristais só diferem por cor (ícones na fase de polimento); Congelamento atinge corredores, não Defensores.

enum Kind { SPEED, HEAL, EXTRA_LIFE, FREEZE, SHIELD }

const NAMES: Array[String] = ["VELOCIDADE", "RECUPERAÇÃO", "VIDA EXTRA", "CONGELAMENTO", "ESCUDO TEMPORAL"]
const COLORS: Array[Color] = [Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.45), Color(0.35, 0.8, 1.0), Color(0.75, 0.95, 1.0), Color(0.75, 0.45, 1.0)]
const FLOAT_HEIGHT := 1.2

@export var scatter_radius := 7.0       # distância do centro do evento onde os cristais caem
@export var pickup_radius := 3.0
@export var lifetime_seconds := 40.0
@export var speed_multiplier := 1.4
@export var speed_seconds := 8.0
@export var heal_points := 6
@export var freeze_radius := 30.0       # adversários a esta distância de quem pegou ficam lentos
@export var freeze_seconds := 5.0
@export var freeze_multiplier := 0.5
@export var shield_seconds := 6.0

var _pickups: Array[Dictionary] = []   # {node, kind, age}
var _timers: Array[Dictionary] = []    # efeitos temporários nos corredores: {runner, property, left}; ao fim a propriedade volta a 1.0


func _ready() -> void:
	EventBus.bonus_drop_requested.connect(_on_drop_requested)
	EventBus.match_ended.connect(_on_match_ended)


func _process(delta: float) -> void:
	_tick_timers(delta)
	if _pickups.is_empty():
		return
	var runners := get_tree().get_nodes_in_group("runners")
	for i in range(_pickups.size() - 1, -1, -1):
		var pickup := _pickups[i]
		pickup["age"] += delta
		var node: Node3D = pickup["node"]
		node.rotate_object_local(Vector3.UP, 2.0 * delta)
		(node.get_child(0) as Node3D).position.y = sin(pickup["age"] * 3.0) * 0.25
		var taker := _find_taker(runners, node.global_position)
		if taker != null:
			_collect(taker, pickup["kind"])
		elif pickup["age"] < lifetime_seconds:
			continue
		node.queue_free()
		_pickups.remove_at(i)


func _on_drop_requested(center: Vector3, count: int) -> void:
	var planet := Services.planet
	if planet == null:
		return
	var up := (center - planet.center).normalized()
	var tangent := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD).normalized()
	var first_angle := randf() * TAU
	for i in count:
		var spread := tangent.rotated(up, first_angle + i * TAU / count)
		var direction := (up + spread * (scatter_radius / planet.radius)).normalized()
		var point := planet.center + direction * (planet.get_surface_radius(direction) + FLOAT_HEIGHT)
		_spawn(point, direction, randi() % Kind.size())


func _spawn(point: Vector3, up: Vector3, kind: int) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLORS[kind]
	mesh.material = material
	var crystal := MeshInstance3D.new()
	crystal.mesh = mesh
	var node := Node3D.new()
	node.name = "Bonus_" + NAMES[kind]
	node.add_child(crystal)
	node.add_to_group("bonus_pickups")   # os bots procuram por aqui
	add_child(node)
	var tangent := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD).normalized()
	node.global_transform = Transform3D(Basis.looking_at(tangent, up, true), point)
	_pickups.append({"node": node, "kind": kind, "age": 0.0})


func _find_taker(runners: Array[Node], point: Vector3) -> PlanetRunner:
	for node in runners:
		var runner := node as PlanetRunner
		if runner.is_active_in_field() and runner.global_position.distance_to(point) <= pickup_radius:
			return runner
	return null


func _collect(runner: PlanetRunner, kind: int) -> void:
	var id := (runner.get_node("Civilization") as Civilization).id
	var health := runner.get_node_or_null("Health") as Health
	var seconds := 0.0
	match kind:
		Kind.SPEED:
			seconds = speed_seconds
			_apply_timed(runner, "speed_multiplier", speed_multiplier, seconds)
		Kind.HEAL:
			if health != null:
				health.heal(heal_points)
		Kind.EXTRA_LIFE:
			if health != null:
				health.grant_extra_heart()
		Kind.FREEZE:
			seconds = freeze_seconds
			_freeze_around(runner, id)
		Kind.SHIELD:
			seconds = shield_seconds
			if health != null:
				health.grant_shield(seconds)
	EventBus.bonus_activated.emit(id, NAMES[kind], seconds)
	print("[Gameplay] Civilização %d pegou o bônus %s." % [id, NAMES[kind]])


# Liga o efeito (propriedade do corredor = valor) por `seconds`; pegar de novo só renova o tempo.
func _apply_timed(runner: PlanetRunner, property: String, value: float, seconds: float) -> void:
	runner.set(property, value)
	for timer in _timers:
		if timer["runner"] == runner and timer["property"] == property:
			timer["left"] = seconds
			return
	_timers.append({"runner": runner, "property": property, "left": seconds})


func _tick_timers(delta: float) -> void:
	for i in range(_timers.size() - 1, -1, -1):
		var timer := _timers[i]
		timer["left"] -= delta
		if timer["left"] <= 0.0:
			if is_instance_valid(timer["runner"]):
				timer["runner"].set(timer["property"], 1.0)
			_timers.remove_at(i)


# Congelamento: corredores ADVERSÁRIOS em campo, dentro do raio, andam mais devagar; cada um é avisado (HUD).
func _freeze_around(caster: PlanetRunner, caster_id: int) -> void:
	for node in get_tree().get_nodes_in_group("runners"):
		var victim := node as PlanetRunner
		var victim_id := (victim.get_node("Civilization") as Civilization).id
		if victim_id != caster_id and victim.is_active_in_field() \
				and victim.global_position.distance_to(caster.global_position) <= freeze_radius:
			_apply_timed(victim, "freeze_multiplier", freeze_multiplier, freeze_seconds)
			EventBus.bonus_activated.emit(victim_id, "CONGELADO", freeze_seconds)


func _on_match_ended() -> void:
	for pickup in _pickups:
		(pickup["node"] as Node).queue_free()
	_pickups.clear()
	for timer in _timers:
		if is_instance_valid(timer["runner"]):
			timer["runner"].set(timer["property"], 1.0)
	_timers.clear()
