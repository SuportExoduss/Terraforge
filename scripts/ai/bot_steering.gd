class_name BotSteering
extends Node
## Cérebro de bot (DD-101): joga como humano com tática — escolhe alvos de expansão em terra livre,
## caça rastros expostos de inimigos para cortá-los e volta para casa antes de se expor demais.
## Mesmo contrato do PlayerSteering (get_steer: -1 esquerda .. +1 direita). Nó filho de um PlanetRunner.
## O recall (DD-123) é do próprio corredor: quando o chão de origem cai, ele sobrepõe este cérebro.

@export var min_sortie_distance := 20.0
@export var max_sortie_distance := 45.0
@export var max_exposure_seconds := 12.0    # tempo máximo exposto antes de abortar e voltar
@export var hunt_range := 35.0              # distância em que um rastro inimigo desperta a caça
@export var steering_gain := 3.4            # por radiano de erro (0,06 por grau no Unity)
@export var decision_interval := 0.5        # sem isso o bot trocaria de alvo 60x/s (frenesi)
@export var bonus_range := 40.0             # distância em que um cristal de bônus desperta a cobiça (SYS-005)

var _runner: PlanetRunner
var _civilization: Civilization
var _sortie_target := Vector3.ZERO
var _has_sortie_target := false
var _returning_home := false
var _exposure := 0.0
var _decision_clock := 0.0
var _hunting := false
var _hunt_point := Vector3.ZERO
var _seeking_bonus := false
var _bonus_point := Vector3.ZERO
var _wobble_seed := randf() * TAU
## DD-127: personalidade. 0,6 = tímido (saídas curtas, volta cedo, caça perto) … 1,6 = ousado. Sem isso bots iguais empatam em ~16,7%.
var ambition := randf_range(0.6, 1.6)

## DD-012 (começo calmo): o 1º minuto prioriza descoberta, não caos. Durante `calm_seconds` o bot não caça rastro inimigo;
## depois o alcance de caça sobe em linha reta até o pleno aos calm+ramp = 45 s.
@export var calm_seconds := 15.0
@export var ramp_seconds := 30.0
var age := 0.0   # segundos correndo (get_steer só roda enquanto ele corre)


func hunt_scale() -> float:
	return clampf((age - calm_seconds) / ramp_seconds, 0.0, 1.0)


func _ready() -> void:
	_runner = get_parent() as PlanetRunner
	_civilization = get_parent().get_node_or_null("Civilization") as Civilization
	if _runner == null or _civilization == null:
		push_error("[BotSteering] %s precisa estar sob um PlanetRunner com crachá Civilization." % name)


## Chamado pelo corredor a cada quadro em que ele corre.
func get_steer() -> float:
	var delta := get_process_delta_time()
	age += delta
	var position := _runner.global_position
	if Services.territory.is_owned_by(_civilization.id, position):
		_returning_home = false   # em casa: novo plano e de volta ao campo
		_has_sortie_target = false
		_exposure = 0.0
	else:
		_exposure += delta

	# Instinto 1 — CAÇA: decide a cada meio segundo e MANTÉM a decisão (compromisso, como um humano).
	_decision_clock += delta
	if _decision_clock >= decision_interval:
		_decision_clock = 0.0
		_hunting = _find_enemy_trail_point()
		_seeking_bonus = _find_bonus_point()
	if _hunting:
		return _steer_towards(_hunt_point)

	# Instinto 2 — RISCO: exposto demais? Aborta e fecha o circuito.
	if _returning_home or _exposure >= max_exposure_seconds * ambition:
		_returning_home = true
		return _steer_towards(_home())

	# Instinto 2b — COBIÇA: cristal de bônus por perto (e sem risco) vale o desvio.
	if _seeking_bonus:
		return _steer_towards(_bonus_point)

	# Instinto 3 — EXPANSÃO: persegue um alvo em terra livre; chegou perto, volta para consolidar.
	if not _has_sortie_target:
		_sortie_target = _pick_sortie_target()
		_has_sortie_target = true
	if position.distance_to(_sortie_target) < 6.0:
		_returning_home = true
		return _steer_towards(_home())
	var wobble := sin(Time.get_ticks_msec() * 0.0004 * TAU + _wobble_seed) * 0.2   # rota menos "robótica"
	return clampf(_steer_towards(_sortie_target) + wobble, -1.0, 1.0)


# "Casa" = onde a nave está agora (DD-100 a muda sozinho: a base registrada acompanha).
func _home() -> Vector3:
	return Services.home_bases.get(_civilization.id, {}).get("position", _runner.global_position)


func _pick_sortie_target() -> Vector3:
	var planet := Services.planet
	var position := _runner.global_position
	var up := (position - planet.center).normalized()
	var fallback := position + _runner.forward * min_sortie_distance
	for attempt in 6:
		var direction := _runner.forward.rotated(up, deg_to_rad(randf_range(-80.0, 80.0)))
		var candidate := position + direction * randf_range(min_sortie_distance, max_sortie_distance) * ambition
		var candidate_up := (candidate - planet.center).normalized()
		candidate = planet.center + candidate_up * planet.get_surface_radius(candidate_up)
		if not Services.territory.is_owned_by(_civilization.id, candidate):
			return candidate
	return fallback


func _find_enemy_trail_point() -> bool:
	var scale := hunt_scale()
	if scale <= 0.0:
		return false
	var best := hunt_range * hunt_range * ambition * ambition * scale * scale
	var found := false
	for trail in Services.trails:
		if trail.owner_id == _civilization.id:
			continue
		var points: Array = trail.points
		for i in range(0, points.size(), 3):   # 1 a cada 3 pontos: precisão suficiente, custo baixo
			var d: float = (points[i] as Vector3).distance_squared_to(_runner.global_position)
			if d < best:
				best = d
				_hunt_point = points[i]
				found = true
	return found


func _find_bonus_point() -> bool:
	var best := bonus_range * bonus_range
	var found := false
	for pickup in get_tree().get_nodes_in_group("bonus_pickups"):
		var d := (pickup as Node3D).global_position.distance_squared_to(_runner.global_position)
		if d < best:
			best = d
			_bonus_point = (pickup as Node3D).global_position
			found = true
	return found


# Quanto o objetivo está à esquerda/direita do focinho decide o volante (direita = giro negativo no Godot).
func _steer_towards(world_point: Vector3) -> float:
	var up := _runner.global_transform.basis.y
	var to_target := (world_point - _runner.global_position).slide(up)
	return clampf(-_runner.forward.signed_angle_to(to_target, up) * steering_gain, -1.0, 1.0)
