class_name HurricaneEvent
extends GlobalEvent
## SYS-004 / DD-107: o FURACÃO. AVISO: o alvo (4 anéis no chão) aparece pequeno e a contagem corre → EXECUÇÃO: nasce
## pequeno, CRESCE e ANDA em círculo máximo; 4 zonas concêntricas: Z1 centro (sucção forte, 4 pts + volta à base),
## Z2 (puxa, -50% de velocidade, 1 pt/s), Z3 (puxa, 1 pt/s), Z4 borda (só empurra para fora, sem dano) → CICATRIZ:
## poeira e destroços espalhados (DD-108) e bônus raro (DD-106). Nunca mexe no território (DD-024).
## ponytail: anéis = discos planos (a borda do maior flutua ~2 u sobre o chão curvo) e o funil é um cone translúcido;
## o "aviso no minimapa" ainda é só o alvo no chão. Troque por malha esférica/shader se incomodar.

const EVENT_NAME := "FURACÃO SE FORMANDO"
const DEBRIS := 8
const ZONE_EDGES := [0.2, 0.45, 0.7, 1.0]   # fim de cada zona (Z1..Z4) como fração do raio atual

@export var storm_seconds := 14.0
@export var start_radius := 7.0
@export var full_radius := 22.0
@export var drift_speed := 7.0          # u/s pelo chão
@export var z1_pull := 25.0             # sucção forte rumo ao olho (u/s)
@export var z2_pull := 4.5              # "puxa muito", mas escapável: o corredor lento ainda faz 6 u/s
@export var z3_pull := 3.0
@export var z4_push := 6.0              # para fora
@export var z1_damage := 4
@export var z2_slow := 0.5
@export var dust_diameter := 32.0

var center_dir := Vector3.UP            # direção (do centro do planeta) do olho
var current_radius := 7.0
var _heading := Vector3.RIGHT
var _zones: Array[MeshInstance3D] = []  # Z1..Z4
var _funnel: MeshInstance3D
var _dust: MeshInstance3D
var _debris: Array[MeshInstance3D] = []
var _debris_phase: Array[float] = []
var _debris_orbit: Array[float] = []    # 0..1 do raio atual
var _debris_height: Array[float] = []
var _scatter: Array[Vector3] = []       # onde cada destroço pousa na cicatriz
var _burn := {}                         # id do corredor -> segundos acumulados dentro de Z2/Z3
var _sent := {}                         # id -> quando foi mandado à base (evita bater de novo na hora)


func _event_name() -> String:
	return EVENT_NAME


func _active_seconds() -> float:
	return storm_seconds


func _setup() -> void:
	var colors := [Color(0.2, 0.22, 0.28), Color(0.38, 0.44, 0.52), Color(0.55, 0.62, 0.7), Color(0.75, 0.8, 0.85)]
	for i in 4:
		_zones.append(make_disc("Z%d" % (i + 1), colors[i]))
	var funnel_mesh := CylinderMesh.new()
	funnel_mesh.top_radius = 1.0
	funnel_mesh.bottom_radius = 0.25
	funnel_mesh.height = 1.0
	funnel_mesh.radial_segments = 16
	funnel_mesh.rings = 1
	var glass := _unshaded(Color(0.7, 0.75, 0.8, 0.4))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	funnel_mesh.material = glass
	_funnel = MeshInstance3D.new()
	_funnel.name = "Funnel"
	_funnel.mesh = funnel_mesh
	_funnel.visible = false
	add_child(_funnel)
	_dust = make_disc("Dust", Color(0.46, 0.41, 0.34))
	var box := BoxMesh.new()
	box.material = _unshaded(Color(0.3, 0.22, 0.16))
	for i in DEBRIS:
		var piece := MeshInstance3D.new()
		piece.name = "Debris%d" % i
		piece.mesh = box
		piece.visible = false
		add_child(piece)
		_debris.append(piece)
		_debris_phase.append(TAU * i / DEBRIS)
		_debris_orbit.append(randf_range(0.25, 0.65))
		_debris_height.append(randf_range(2.0, 9.0))
		_scatter.append(Vector3.UP)


func _begin_warning() -> bool:
	var start := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()   # uniforme na esfera
	plan(start, start.cross(Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))))
	print("[World] FURACÃO se formando! (DD-107)")
	return true


## Fixa o ponto de nascimento e a direção da viagem (também usada pelos testes).
func plan(start: Vector3, heading: Vector3) -> void:
	center_dir = start.normalized()
	_heading = heading.slide(center_dir).normalized()
	current_radius = start_radius
	_burn.clear()
	_sent.clear()
	_funnel.visible = false
	_dust.visible = false
	for piece in _debris:
		piece.visible = false
	_place_target()


func _begin_active() -> void:
	_funnel.visible = true
	for piece in _debris:
		piece.visible = true


func _tick_active(delta: float) -> bool:
	var planet := Services.planet
	var axis := center_dir.cross(_heading)   # o olho anda em círculo máximo
	var angle := drift_speed * delta / planet.radius
	center_dir = center_dir.rotated(axis, angle)
	_heading = _heading.rotated(axis, angle)
	current_radius = _radius_at(clock / storm_seconds)
	_place_target()
	_place_funnel()
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		if runner.is_active_in_field():
			_affect(runner, delta)
		else:
			runner.slow_multiplier = 1.0
	return clock >= storm_seconds


func _begin_scar() -> void:
	_release_runners()
	for zone in _zones:
		zone.visible = false
	_funnel.visible = false
	place_disc(_dust, center_dir, dust_diameter)
	var b := ground_basis(center_dir)
	for i in DEBRIS:
		var offset := (b.x * cos(randf() * TAU) + b.z * sin(randf() * TAU)) * randf_range(3.0, 14.0)
		_scatter[i] = (center_dir + offset / Services.planet.radius).normalized()
		var flat := ground_basis(_scatter[i]).rotated(_scatter[i], randf() * TAU)
		_debris[i].global_transform = Transform3D(flat, ground_point(_scatter[i]) + _scatter[i] * 0.4)
		_debris[i].scale = Vector3(1.6, 0.6, 1.1)
		_debris[i].visible = true
	EventBus.bonus_drop_requested.emit(ground_point(center_dir), randi_range(3, 4))   # bônus RARO
	print("[World] Furacão se desfez: poeira e destroços (DD-108).")


func _tick_scar(life: float) -> void:
	_dust.scale = Vector3(dust_diameter * life, 0.12, dust_diameter * life)
	for piece in _debris:
		piece.scale = Vector3(1.6, 0.6, 1.1) * life


func _hide() -> void:
	_release_runners()
	for zone in _zones:
		zone.visible = false
	_funnel.visible = false
	_dust.visible = false
	for piece in _debris:
		piece.visible = false


## Qual zona (1..4) cobre esta distância ao olho; 0 = fora do furacão.
func zone_of(distance: float) -> int:
	for i in 4:
		if distance <= current_radius * ZONE_EDGES[i]:
			return i + 1
	return 0


func _affect(runner: PlanetRunner, delta: float) -> void:
	var planet := Services.planet
	var unit := (runner.global_position - planet.center).normalized()
	var zone := zone_of(acos(clampf(unit.dot(center_dir), -1.0, 1.0)) * planet.radius)
	var inward := (center_dir - unit * unit.dot(center_dir)).normalized()   # tangente rumo ao olho
	var id := runner.get_instance_id()
	var health := runner.get_node_or_null("Health") as Health
	runner.slow_multiplier = z2_slow if zone == 2 else 1.0
	match zone:
		1:
			runner.push = inward * z1_pull
			if health != null and clock - _sent.get(id, -99.0) > 2.0:
				_sent[id] = clock
				health.take_damage(z1_damage, "FURACÃO")
				if health.points > 0:
					health.return_to_force_field()
		2:
			runner.push = inward * z2_pull
		3:
			runner.push = inward * z3_pull
		4:
			runner.push = -inward * z4_push   # a borda só empurra
	if zone == 2 or zone == 3:
		_burn[id] = _burn.get(id, 0.0) + delta
		if _burn[id] >= 1.0:
			_burn[id] -= 1.0
			if health != null:
				health.take_damage(1, "FURACÃO")
	else:
		_burn[id] = 0.0


func _radius_at(phase: float) -> float:
	if phase < 0.35:
		return lerpf(start_radius, full_radius, phase / 0.35)    # nasce pequeno e cresce
	if phase > 0.85:
		return lerpf(full_radius, start_radius, (phase - 0.85) / 0.15)   # e se desfaz
	return full_radius


func _release_runners() -> void:
	for node in get_tree().get_nodes_in_group("runners"):
		(node as PlanetRunner).slow_multiplier = 1.0


# Alvo no chão: Z1 (mais escura) por cima de Z4 (mais clara), com um fio de altura para não brigarem (z-fight).
func _place_target() -> void:
	for i in 4:
		place_disc(_zones[i], center_dir, current_radius * 2.0 * ZONE_EDGES[i])
		_zones[i].global_position += center_dir * 0.05 * (3 - i)


func _place_funnel() -> void:
	var height := 6.0 + current_radius * 0.5
	_funnel.global_transform = Transform3D(ground_basis(center_dir), ground_point(center_dir) + center_dir * height * 0.5)
	_funnel.scale = Vector3(current_radius * 0.6, height, current_radius * 0.6)
	var b := ground_basis(center_dir)
	for i in DEBRIS:
		var a := _debris_phase[i] + clock * 2.5
		var offset := (b.x * cos(a) + b.z * sin(a)) * current_radius * _debris_orbit[i]
		var direction := (center_dir + offset / Services.planet.radius).normalized()
		_debris[i].global_transform = Transform3D(Basis(direction, a * 2.0), ground_point(direction) + direction * _debris_height[i])
		_debris[i].scale = Vector3(1.4, 0.7, 1.0)


func _focus_direction() -> Vector3:
	return center_dir


func _focus_heading() -> Vector3:
	return _heading
