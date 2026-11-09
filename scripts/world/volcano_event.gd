class_name VolcanoEvent
extends GlobalEvent
## SYS-004 / DD-107: o VULCÃO. AVISO: o chão escurece e o cone mal desponta (a contagem corre) → EXECUÇÃO: o cone
## sobe e cospe bolas de lava em arco; cada bola mostra a mancha vermelha de onde vai cair e, ao cair, tira 1 ponto de
## quem estiver embaixo; 4 bolas ACUMULADAS na mesma erupção = 1 coração (4 pts) e VOLTA À BASE (DD-107) →
## CICATRIZ: o cone afunda, sobram solo escuro e lava sólida (DD-108) e cristais de bônus (DD-106). Nunca mexe no
## território (DD-024).
## ponytail: bola = esfera sem partículas; o "chão treme" é só o solo escurecendo e o cone despontando.

const EVENT_NAME := "VULCÃO EM ERUPÇÃO"
const BALLS := 6
const BALLS_FOR_RETURN := 4   # DD-107: 4 bolas acumuladas = 1 coração + volta à base

@export var eruption_seconds := 10.0
@export var launch_interval := 0.8
@export var flight_seconds := 1.4
@export var arc_height := 16.0
@export var min_range := 8.0
@export var max_range := 38.0
@export var hit_radius := 3.0
@export var cone_height := 7.0
@export var cone_radius := 6.0
@export var ball_diameter := 2.2
@export var soil_diameter := 36.0
@export var lava_diameter := 14.0

var _spot := Vector3.UP         # direção (do centro) da boca do vulcão
var _cone: MeshInstance3D
var _soil: MeshInstance3D
var _lava: MeshInstance3D
var _balls: Array[MeshInstance3D] = []
var _marks: Array[MeshInstance3D] = []
var _age: Array[float] = []     # idade de cada bola em voo; < 0 = livre
var _target: Array[Vector3] = []
var _next_launch := 0.0
var _hits := {}                 # id do corredor -> bolas acumuladas nesta erupção


func _event_name() -> String:
	return EVENT_NAME


func _active_seconds() -> float:
	return eruption_seconds


func _setup() -> void:
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = cone_radius
	cone_mesh.height = 1.0
	cone_mesh.radial_segments = 16
	cone_mesh.rings = 1
	cone_mesh.material = _unshaded(Color(0.22, 0.15, 0.13))
	_cone = MeshInstance3D.new()
	_cone.name = "Cone"
	_cone.mesh = cone_mesh
	_cone.visible = false
	add_child(_cone)
	_soil = make_disc("Soil", Color(0.14, 0.09, 0.08))
	_lava = make_disc("Lava", Color(0.55, 0.14, 0.05))
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.5
	ball_mesh.height = 1.0
	ball_mesh.material = _unshaded(Color(1.0, 0.45, 0.08))
	for i in BALLS:
		var ball := MeshInstance3D.new()
		ball.name = "Ball%d" % i
		ball.mesh = ball_mesh
		ball.visible = false
		add_child(ball)
		_balls.append(ball)
		_marks.append(make_disc("Mark%d" % i, Color(1.0, 0.25, 0.05)))
		_age.append(-1.0)
		_target.append(Vector3.UP)


func _begin_warning() -> bool:
	plan(Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized())   # uniforme na esfera
	print("[World] VULCÃO prestes a irromper! (DD-107)")
	return true


## Fixa a boca do vulcão (também usada pelos testes).
func plan(spot: Vector3) -> void:
	_spot = spot.normalized()
	_hits.clear()
	_clear_balls()
	_lava.visible = false
	place_disc(_soil, _spot, soil_diameter * 0.3)
	_place_cone(0.15)


func _tick_warning(remaining: float, _delta: float) -> void:
	var progress := clampf(1.0 - remaining / warning_seconds, 0.0, 1.0)
	place_disc(_soil, _spot, soil_diameter * lerpf(0.3, 1.0, progress))   # o chão escurece, o cone desponta
	_place_cone(lerpf(0.15, 1.0, progress) * cone_height * 0.2)


func _begin_active() -> void:
	_hits.clear()
	_next_launch = 0.5
	place_disc(_soil, _spot, soil_diameter)


func _tick_active(delta: float) -> bool:
	_place_cone(cone_height * clampf(clock / 1.5, 0.2, 1.0))   # o cone sobe e fica
	_next_launch -= delta
	if _next_launch <= 0.0 and clock < eruption_seconds - flight_seconds:
		_next_launch += launch_interval
		_launch()
	_fly_balls(delta)
	return clock >= eruption_seconds


func _begin_scar() -> void:
	_clear_balls()
	place_disc(_lava, _spot, lava_diameter)
	EventBus.bonus_drop_requested.emit(ground_point(_spot), randi_range(2, 3))
	print("[World] Vulcão afundou: solo escuro, lava sólida e cristais (DD-108).")


func _tick_scar(life: float) -> void:
	var sink := clampf((life - 0.85) / 0.15, 0.0, 1.0)   # o cone afunda nos primeiros 15% da cicatriz
	_cone.visible = sink > 0.0
	if _cone.visible:
		_place_cone(cone_height * sink)
	_soil.scale = Vector3(soil_diameter * life, 0.15, soil_diameter * life)
	_lava.scale = Vector3(lava_diameter * life, 0.18, lava_diameter * life)


func _hide() -> void:
	_cone.visible = false
	_soil.visible = false
	_lava.visible = false
	_clear_balls()


## Uma bola de lava caiu em cima de `runner`: 1 ponto; a 4ª acumulada devolve ao campo de força (DD-107).
func hit(runner: PlanetRunner) -> void:
	var health := runner.get_node_or_null("Health") as Health
	if health == null:
		return
	health.take_damage(1)
	var id := runner.get_instance_id()
	var count: int = _hits.get(id, 0) + 1
	if count >= BALLS_FOR_RETURN:
		count = 0
		if health.points > 0:
			health.return_to_force_field()
	_hits[id] = count


func _launch() -> void:
	var free := _age.find_custom(func(a: float): return a < 0.0)
	if free < 0:
		return
	var tangent := _spot.cross(Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))).normalized()
	var distance := randf_range(min_range, max_range)
	_target[free] = _spot.rotated(_spot.cross(tangent), distance / Services.planet.radius)
	_age[free] = 0.0
	place_disc(_marks[free], _target[free], hit_radius * 2.0)
	_balls[free].scale = Vector3.ONE * ball_diameter
	_balls[free].visible = true
	_place_ball(free)


func _fly_balls(delta: float) -> void:
	for i in BALLS:
		if _age[i] < 0.0:
			continue
		_age[i] += delta
		if _age[i] < flight_seconds:
			_place_ball(i)
			continue
		var landing := ground_point(_target[i])
		for node in get_tree().get_nodes_in_group("runners"):
			var runner := node as PlanetRunner
			if runner.is_active_in_field() and runner.global_position.distance_to(landing) <= hit_radius:
				hit(runner)
		_free_ball(i)


func _place_ball(i: int) -> void:
	var t := _age[i] / flight_seconds
	var direction := _spot.slerp(_target[i], t)
	var height := lerpf(cone_height, 0.0, t) + arc_height * 4.0 * t * (1.0 - t) + ball_diameter * 0.5
	_balls[i].global_position = ground_point(direction) + direction * height


func _free_ball(i: int) -> void:
	_age[i] = -1.0
	_balls[i].visible = false
	_marks[i].visible = false


func _clear_balls() -> void:
	for i in BALLS:
		_free_ball(i)


func _place_cone(height: float) -> void:
	var h := maxf(height, 0.05)
	_cone.global_transform = Transform3D(ground_basis(_spot), ground_point(_spot) + _spot * (h * 0.5 - 0.5))
	_cone.scale = Vector3(1.0, h, 1.0)
	_cone.visible = true


func _focus_direction() -> Vector3:
	return _spot
