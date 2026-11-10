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

const RARE: Array[int] = [Kind.EXTRA_LIFE, Kind.SHIELD]   # os dois mais fortes (o GDMD não lista quais são "raros": interpretação)
const RARE_AFTER_SECONDS := 45.0                          # Cap.03 P03 REGRAS: "nenhum bônus raro aparece antes de 45 segundos"
const STORED: Array[int] = [Kind.SPEED, Kind.FREEZE, Kind.SHIELD]   # Cap.03 P08: vão para o estoque e o dono decide quando usar (interpretação)
const STOCK_LIMIT := 3                                    # estoque cheio: o cristal desses tipos fica no chão
const NAMES: Array[String] =["VELOCIDADE", "RECUPERAÇÃO", "VIDA EXTRA", "CONGELAMENTO", "ESCUDO TEMPORAL"]
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
@export var bot_use_delay := 4.0        # bots usam o que guardaram depois de uns segundos

var _pickups: Array[Dictionary] = []   # {node, kind, age}
var _timers: Array[Dictionary] = []    # efeitos temporários nos corredores: {runner, property, left}; ao fim a propriedade volta a 1.0
var _stock: Dictionary = {}            # id da civilização -> Array[int] de tipos guardados (o mais antigo sai primeiro)
var _bot_wait: Dictionary = {}         # id do bot -> segundos desde que ele passou a ter estoque


func _ready() -> void:
	EventBus.bonus_drop_requested.connect(_on_drop_requested)
	EventBus.match_ended.connect(_on_match_ended)


func _process(delta: float) -> void:
	_tick_timers(delta)
	_tick_bots(delta)
	if _pickups.is_empty():
		return
	var runners := get_tree().get_nodes_in_group("runners")
	for i in range(_pickups.size() - 1, -1, -1):
		var pickup := _pickups[i]
		pickup["age"] += delta
		var node: Node3D = pickup["node"]
		node.rotate_object_local(Vector3.UP, 2.0 * delta)
		(node.get_child(0) as Node3D).position.y = sin(pickup["age"] * 3.0) * 0.25
		var taker := _find_taker(runners, node.global_position, pickup["kind"])
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
	var elapsed := elapsed_seconds()
	for i in count:
		var spread := tangent.rotated(up, first_angle + i * TAU / count)
		var direction := (up + spread * (scatter_radius / planet.radius)).normalized()
		var point := planet.center + direction * (planet.get_surface_radius(direction) + FLOAT_HEIGHT)
		_spawn(point, direction, pick_kind(elapsed))


## Segundos de partida já corridos (sem relógio na cena, conta como "já passou": cena de teste isolada).
func elapsed_seconds() -> float:
	var timer := get_tree().get_first_node_in_group("match_timer") as MatchTimer
	return INF if timer == null else timer.duration_seconds - timer.seconds_left()


## Sorteia o tipo do cristal; antes de RARE_AFTER_SECONDS os raros ficam fora do sorteio.
func pick_kind(elapsed: float) -> int:
	var pool: Array = range(Kind.size()).filter(func(k): return elapsed >= RARE_AFTER_SECONDS or not k in RARE)
	return pool.pick_random()


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


func _find_taker(runners: Array[Node], point: Vector3, kind: int) -> PlanetRunner:
	for node in runners:
		var runner := node as PlanetRunner
		if runner.is_active_in_field() and runner.global_position.distance_to(point) <= pickup_radius 				and not (kind in STORED and stock_of(_id_of(runner)).size() >= STOCK_LIMIT):
			return runner
	return null


func _id_of(runner: PlanetRunner) -> int:
	return (runner.get_node("Civilization") as Civilization).id


## Estoque da civilização (cópia): tipos guardados, o próximo a ser usado primeiro.
func stock_of(id: int) -> Array:
	return (_stock.get(id, []) as Array).duplicate()


## Usa o bônus guardado mais antigo; false se não há estoque ou o dono não está em campo.
func use_next(id: int) -> bool:
	var stock: Array = _stock.get(id, [])
	if stock.is_empty():
		return false
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		if _id_of(runner) == id and runner.is_active_in_field():
			_activate(runner, stock.pop_front())
			_announce_stock(id)
			return true
	return false


func _announce_stock(id: int) -> void:
	var names: Array = (_stock.get(id, []) as Array).map(func(k): return NAMES[k])
	EventBus.bonus_stock_changed.emit(id, names)


# Bots não têm teclado: usam o estoque `bot_use_delay` segundos depois de passarem a ter algo guardado.
func _tick_bots(delta: float) -> void:
	for id in _stock.keys():
		if id == Civilization.PLAYER_ID:
			continue
		if (_stock[id] as Array).is_empty():
			_bot_wait.erase(id)
			continue
		_bot_wait[id] = _bot_wait.get(id, 0.0) + delta
		if _bot_wait[id] >= bot_use_delay:
			_bot_wait.erase(id)
			use_next(id)


func _collect(runner: PlanetRunner, kind: int) -> void:
	if kind in STORED:
		var id := _id_of(runner)
		var stock: Array = _stock.get(id, [])
		stock.append(kind)
		_stock[id] = stock
		_announce_stock(id)
		print("[Gameplay] Civilização %d guardou o bônus %s (%d/%d)." % [id, NAMES[kind], stock.size(), STOCK_LIMIT])
	else:
		_activate(runner, kind)


func _activate(runner: PlanetRunner, kind: int) -> void:
	var id := _id_of(runner)
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
	_stock.clear()
	_bot_wait.clear()
