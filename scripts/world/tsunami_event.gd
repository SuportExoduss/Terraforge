class_name TsunamiEvent
extends GlobalEvent
## SYS-004 / DD-107: o TSUNAMI. Uma onda enorme (faixa larga) atravessa meia volta do planeta sem parar, numa
## direção sorteada. AVISO: a espuma aparece baixa no ponto de partida e a contagem corre → EXECUÇÃO: a onda
## avança em círculo máximo; quem fica na faixa leva o dano da parte mais funda em que entrou, UMA vez por
## passagem (espuma 1, parte média 2, centro 3 — o centro ainda EMPURRA muito) → CICATRIZ: poça no ponto final
## que seca (DD-108) e o bônus fica lá (DD-106). Nunca mexe no território (DD-024).
## ponytail: a faixa é uma fila de caixas translúcidas (sem shader de água); empurra só na direção da onda.

const EVENT_NAME := "TSUNAMI VINDO"
const SEGMENTS := 17

@export var wave_speed := 24.0              # unidades/s pelo chão
@export var travel_degrees := 180.0         # meia volta no planeta
@export var half_width := 40.0              # metade da largura (lateral à direção)
@export var center_half := 3.0              # metade da espessura do centro (3 pts + empurra)
@export var middle_half := 6.0              # parte média (2 pts)
@export var foam_half := 9.0                # espuma (1 pt)
@export var push_speed := 30.0
@export var wave_height := 3.0
@export var puddle_diameter := 40.0

var _start := Vector3.UP        # direção (unitária, do centro) do ponto de partida
var _travel := Vector3.RIGHT    # tangente de avanço em _start
var _normal := Vector3.BACK     # eixo do plano da trajetória (start × travel)
var _angle := 0.0               # quanto a onda já andou (rad)
var _segments: Array[MeshInstance3D] = []
var _puddle: MeshInstance3D
var _applied := {}              # id do corredor -> pontos já cobrados nesta passagem


func _event_name() -> String:
	return EVENT_NAME


func _active_seconds() -> float:
	var radius: float = Services.planet.radius if Services.planet != null else 100.0
	return deg_to_rad(travel_degrees) * radius / wave_speed


func _setup() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.25, 0.65, 1.0, 0.6)
	for i in SEGMENTS:
		var mesh := BoxMesh.new()
		mesh.material = material
		var segment := MeshInstance3D.new()
		segment.name = "Wave%d" % i
		segment.mesh = mesh
		segment.visible = false
		add_child(segment)
		_segments.append(segment)
	_puddle = make_disc("Puddle", Color(0.15, 0.4, 0.65))


func _begin_warning() -> bool:
	var start := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()   # uniforme na esfera
	var spin := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))
	plan(start, spin.slide(start).normalized())
	print("[World] TSUNAMI a caminho! (DD-107)")
	return true


## Fixa a trajetória (também usada pelos testes). `travel` precisa ser tangente em `start`.
func plan(start: Vector3, travel: Vector3) -> void:
	_start = start.normalized()
	_travel = travel.slide(_start).normalized()
	_normal = _start.cross(_travel)
	_angle = 0.0
	_applied.clear()
	_place_wave(0.15)


func _tick_warning(remaining: float, _delta: float) -> void:
	_place_wave(lerpf(0.15, 1.0, clampf(1.0 - remaining / warning_seconds, 0.0, 1.0)))   # a onda se levanta


func _begin_active() -> void:
	_place_wave(1.0)


func _tick_active(delta: float) -> bool:
	var planet := Services.planet
	_angle += wave_speed * delta / planet.radius
	_place_wave(1.0)
	var front := _front_point(_angle)
	var ahead := _front_tangent(_angle)
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		if not runner.is_active_in_field():
			continue
		var unit := (runner.global_position - planet.center).normalized()
		if unit.dot(front) <= 0.0 or absf(asin(clampf(unit.dot(_normal), -1.0, 1.0))) * planet.radius > half_width:
			continue   # no outro hemisfério ou fora da largura da onda
		var depth := absf(unit.dot(ahead)) * planet.radius   # distância ao centro da onda, ao longo do avanço
		var points := 3 if depth <= center_half else (2 if depth <= middle_half else (1 if depth <= foam_half else 0))
		if points == 0:
			continue
		if points == 3:
			runner.push = ahead.slide(unit) * push_speed
		var id := runner.get_instance_id()
		var already: int = _applied.get(id, 0)
		if points > already:
			_applied[id] = points
			var health := runner.get_node_or_null("Health") as Health
			if health != null:
				health.take_damage(points - already, "TSUNAMI")
	return _angle >= deg_to_rad(travel_degrees)


func _begin_scar() -> void:
	for segment in _segments:
		segment.visible = false
	var end := _front_point(deg_to_rad(travel_degrees))
	place_disc(_puddle, end, puddle_diameter)
	EventBus.bonus_drop_requested.emit(Services.planet.center + end * Services.planet.get_surface_radius(end), randi_range(1, 3))
	print("[World] Tsunami passou: poça no ponto final (DD-108).")


func _tick_scar(life: float) -> void:
	var diameter := puddle_diameter * life
	_puddle.scale = Vector3(diameter, 0.12, diameter)


func _hide() -> void:
	for segment in _segments:
		segment.visible = false
	_puddle.visible = false


func _front_point(angle: float) -> Vector3:
	return _start * cos(angle) + _travel * sin(angle)


func _front_tangent(angle: float) -> Vector3:
	return -_start * sin(angle) + _travel * cos(angle)


# Fila de caixas ao longo do arco lateral que passa pelo centro da onda; `rise` 0..1 é a altura (aviso = baixa).
func _place_wave(rise: float) -> void:
	var planet := Services.planet
	var front := _front_point(_angle)
	var ahead := _front_tangent(_angle)
	var step := 2.0 * half_width / planet.radius / SEGMENTS
	for i in SEGMENTS:
		var lateral := (i - (SEGMENTS - 1) * 0.5) * step
		var direction := (front * cos(lateral) + _normal * sin(lateral)).normalized()
		var height := wave_height * rise
		var segment := _segments[i]
		segment.global_transform = Transform3D(Basis.looking_at(ahead, direction, true),
				planet.center + direction * (planet.get_surface_radius(direction) + height * 0.5))
		segment.scale = Vector3(step * planet.radius * 1.05, height, foam_half * 2.0)
		segment.visible = true


func _focus_direction() -> Vector3:
	return _front_point(_angle)


func _focus_heading() -> Vector3:
	return _front_tangent(_angle)
