class_name SkillSystem
extends Node
## DD-182 (Passo 143): SPRINT, a corrida rápida para a frente que o jogador aciona (botão da HUD ou SHIFT).
## O corredor anda a `sprint_multiplier` da velocidade por `sprint_seconds` e a carga volta `sprint_cooldown` segundos DEPOIS do
## uso (uma carga só, igual para todos). Só vale com o corredor em campo; a pausa da árvore congela os relógios. O efeito escala
## `move_speed` (e desfaz dividindo), então soma-se por multiplicação ao bônus Velocidade, ao Congelamento e à lentidão dos eventos.
## Fala com o resto só por sinais (sprint_requested entra, sprint_used sai) e pelo grupo "runners".
## Bots arrancam quando há um rival por perto (perseguir ou fugir).
## ponytail: sem estado por corredor além de dois dicionários; o online (comando no protocolo) entra depois.
## DD-183 (Passo 147): HABILIDADE ESPECIAL DO BIOMA (botão da HUD ou E), recarga de 15 s contada do uso; a 1ª carga fica pronta 15 s depois
## da largada. A habilidade é a do bioma que a civilização usa (CivilizationCatalog.biome_of): Laço, Pulso EMP, Cura, Manobra, Canhonada,
## Armadura de Gelo. Habilidade ofensiva ou de cura sem alvo/sem o que curar NÃO gasta a carga. Efeitos de velocidade/curva escalam
## `move_speed`/`turn_speed_degrees` e desfazem dividindo (como o sprint); empurrão usa `push`; cura e escudo usam o Health do corredor.
## Entra ability_requested; saem ability_used (som/efeitos) e ability_charging (a HUD mostra a recarga).

@export var sprint_multiplier := 1.8
@export var sprint_seconds := 0.8
@export var sprint_cooldown := 3.5
@export var bots_sprint := true
@export var bot_trigger_radius := 10.0   # rival em campo a esta distância (ou menos): o bot arranca
@export var ability_cooldown := 15.0     # DD-183
@export var lasso_range := 30.0          # Laço: o rival mais próximo até aqui anda a lasso_factor por lasso_seconds
@export var lasso_factor := 0.5
@export var lasso_seconds := 3.0
@export var emp_radius := 18.0           # Pulso EMP: todos os rivais até aqui andam a emp_factor por emp_seconds
@export var emp_factor := 0.6
@export var emp_seconds := 2.5
@export var heal_points := 4             # Cura da Floresta: 1 coração (4 pontos)
@export var trick_turn := 1.6            # Manobra: a curva fica 1,6x mais fechada por trick_seconds
@export var trick_seconds := 3.0
@export var cannon_radius := 16.0        # Canhonada: os rivais até aqui são empurrados (26,8 u/s que decaem a 60 u/s² = ~6 u de recuo)
@export var cannon_push := 26.8
@export var frost_seconds := 2.5         # Armadura de Gelo: escudo (Health.grant_shield)
@export var bot_danger_radius := 20.0    # bot usa Manobra/Armadura com rival em campo até aqui

var _running: Dictionary = {}     # id da civilização -> {runner, left}: sprints em curso
var _cooldowns: Dictionary = {}   # id -> segundos que faltam para a próxima carga (sem entrada = pronto)
var _ability_cd: Dictionary = {}  # DD-183: id -> segundos que faltam para a habilidade (sem entrada = pronta)
var _kinds: Dictionary = {}       # id -> id da habilidade ("lasso"...) do bioma dele nesta partida
var _timed: Dictionary = {}       # "habilidade:instância" -> {runner, left, prop, factor}: efeitos de velocidade/curva em curso


func _ready() -> void:
	EventBus.sprint_requested.connect(use_sprint)
	EventBus.ability_requested.connect(use_ability)
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_reset)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SHIFT:
		use_sprint(Civilization.PLAYER_ID)
	elif key != null and key.pressed and not key.echo and key.keycode == KEY_E:
		use_ability(Civilization.PLAYER_ID)


func _process(delta: float) -> void:
	_tick_running(delta)
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	_tick_timed(delta)
	for id in _ability_cd.keys():
		_ability_cd[id] -= delta
		if _ability_cd[id] <= 0.0:
			_ability_cd.erase(id)
	if bots_sprint:
		_tick_bots()
		_tick_bot_abilities()


## A próxima carga está pronta? (sem corredor em campo ela também "está pronta"; use_sprint confere o campo.)
func sprint_ready(id: int) -> bool:
	return not _cooldowns.has(id)


## Segundos que faltam para a carga (0 = pronta).
func sprint_cooldown_left(id: int) -> float:
	return _cooldowns.get(id, 0.0)


func sprint_running(id: int) -> bool:
	return _running.has(id)


## Liga o sprint do corredor `id`; false se ainda recarrega ou ele não está em campo.
func use_sprint(id: int) -> bool:
	if _cooldowns.has(id):
		return false
	var runner := _runner_of(id)
	if runner == null or not runner.is_active_in_field():
		return false
	runner.move_speed *= sprint_multiplier
	_running[id] = {"runner": runner, "left": sprint_seconds}
	_cooldowns[id] = sprint_cooldown
	EventBus.sprint_used.emit(id, sprint_cooldown)
	GameLog.say("[Gameplay] Civilização %d acionou o sprint." % id)
	return true


## A habilidade está pronta? (como no sprint, use_ability confere o campo.)
func ability_ready(id: int) -> bool:
	return not _ability_cd.has(id)


## Segundos que faltam para a habilidade (0 = pronta).
func ability_cooldown_left(id: int) -> float:
	return _ability_cd.get(id, 0.0)


## O id da habilidade ("lasso", "emp", "heal", "trick", "cannon", "frost") que a civilização `id` tem nesta partida.
func ability_kind(id: int) -> String:
	if not _kinds.has(id):
		_kinds[id] = CivilizationCatalog.ability_of(CivilizationCatalog.biome_of(id))["id"]
	return _kinds[id]


## Dispara a habilidade do corredor `id`; false se ainda recarrega, ele não está em campo ou ela não teria efeito (sem alvo / vida cheia).
func use_ability(id: int) -> bool:
	if _ability_cd.has(id):
		return false
	var runner := _runner_of(id)
	if runner == null or not runner.is_active_in_field():
		return false
	var kind := ability_kind(id)
	if not _cast(kind, runner):
		return false
	_ability_cd[id] = ability_cooldown
	EventBus.ability_used.emit(id, kind)
	EventBus.ability_charging.emit(id, ability_cooldown, kind)
	GameLog.say("[Gameplay] Civilização %d usou a habilidade %s." % [id, kind])
	return true


func _cast(kind: String, runner: PlanetRunner) -> bool:
	var health := runner.get_node_or_null("Health") as Health
	match kind:
		"lasso":
			var target := _rivals_within(runner, lasso_range, true)
			if target.is_empty():
				return false
			_scale(kind, target[0], "move_speed", lasso_factor, lasso_seconds)
			_ring(target[0], 5.0, kind)
		"emp":
			var hit := _rivals_within(runner, emp_radius)
			if hit.is_empty():
				return false
			for rival in hit:
				_scale(kind, rival, "move_speed", emp_factor, emp_seconds)
			_ring(runner, emp_radius, kind)
		"heal":
			if health == null or health.points >= health.max_points:
				return false
			health.heal(heal_points)
			_ring(runner, 5.0, kind)
		"trick":
			_scale(kind, runner, "turn_speed_degrees", trick_turn, trick_seconds)
			_ring(runner, 5.0, kind)
		"cannon":
			var hit := _rivals_within(runner, cannon_radius)
			if hit.is_empty():
				return false
			for rival in hit:
				var up: Vector3 = (rival.global_position - Services.planet.center).normalized()
				var away: Vector3 = (rival.global_position - runner.global_position).slide(up)
				rival.push = (away.normalized() if away.length_squared() > 0.0001 else runner.forward) * cannon_push
			_ring(runner, cannon_radius, kind)
		"frost":
			if health == null:
				return false
			health.grant_shield(frost_seconds)
			_ring(runner, 5.0, kind)
		_:
			return false
	return true


## Os rivais em campo a até `radius` de `runner` (outra civilização), do mais perto ao mais longe; `only_nearest` devolve no máximo um.
func _rivals_within(runner: PlanetRunner, radius: float, only_nearest := false) -> Array:
	var found: Array = []
	for node in get_tree().get_nodes_in_group("runners"):
		var other := node as PlanetRunner
		if other == runner or not other.is_active_in_field():
			continue
		var mine := runner.get_node_or_null("Civilization") as Civilization
		var theirs := other.get_node_or_null("Civilization") as Civilization
		if mine != null and theirs != null and mine.id == theirs.id:
			continue
		if other.global_position.distance_to(runner.global_position) <= radius:
			found.append(other)
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(runner.global_position) < b.global_position.distance_to(runner.global_position))
	return found.slice(0, 1) if only_nearest else found


## Multiplica `prop` do corredor por `factor` durante `seconds` e desfaz dividindo; repetir a mesma habilidade no mesmo corredor só renova o tempo.
func _scale(kind: String, runner: PlanetRunner, prop: String, factor: float, seconds: float) -> void:
	var key := "%s:%d" % [kind, runner.get_instance_id()]
	if _timed.has(key):
		_timed[key]["left"] = seconds
		return
	runner.set(prop, runner.get(prop) * factor)
	_timed[key] = {"runner": runner, "left": seconds, "prop": prop, "factor": factor}


func _tick_timed(delta: float) -> void:
	for key in _timed.keys():
		_timed[key]["left"] -= delta
		if _timed[key]["left"] <= 0.0 or not is_instance_valid(_timed[key]["runner"]):
			_undo(key)


func _undo(key: String) -> void:
	var entry: Dictionary = _timed[key]
	if is_instance_valid(entry["runner"]):
		entry["runner"].set(entry["prop"], entry["runner"].get(entry["prop"]) / entry["factor"])
	_timed.erase(key)


## Anel que abre no chão ao redor de `at` (cor viva do bioma da habilidade) e some em meio segundo.
func _ring(at: Node3D, radius: float, kind: String) -> void:
	var color := Color.WHITE
	for index in CivilizationCatalog.count():
		if CivilizationCatalog.ABILITIES[index]["id"] == kind:
			color = Color.from_hsv(CivilizationCatalog.soil_color(index + 1).h, 0.6, 1.0, 0.85)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material = material
	var ring := MeshInstance3D.new()
	ring.name = "AbilityRing"
	ring.mesh = mesh
	at.get_parent().add_child(ring)
	var up: Vector3 = (at.global_position - Services.planet.center).normalized()
	ring.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), at.global_position)
	ring.scale = Vector3.ONE * 0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * radius, 0.45)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)


func _runner_of(id: int) -> PlanetRunner:
	for node in get_tree().get_nodes_in_group("runners"):
		var civ := node.get_node_or_null("Civilization") as Civilization
		if civ != null and civ.id == id:
			return node as PlanetRunner
	return null


func _tick_running(delta: float) -> void:
	for id in _running.keys():
		var run: Dictionary = _running[id]
		run["left"] -= delta
		var runner: PlanetRunner = run["runner"]
		# acabou o tempo, ou o corredor saiu do campo (eliminado/voltando ao domo): a velocidade volta
		if run["left"] <= 0.0 or not is_instance_valid(runner) or not runner.is_active_in_field():
			_stop(id)


func _stop(id: int) -> void:
	var runner: PlanetRunner = _running[id]["runner"]
	if is_instance_valid(runner):
		runner.move_speed /= sprint_multiplier
	_running.erase(id)


# Bot: com a carga pronta e um rival em campo ao alcance, arranca.
func _tick_bots() -> void:
	var runners := get_tree().get_nodes_in_group("runners")
	for node in runners:
		var bot := node as PlanetRunner
		var civ := bot.get_node_or_null("Civilization") as Civilization
		if civ == null or not _is_bot(bot) or _cooldowns.has(civ.id) or not bot.is_active_in_field():
			continue
		for other_node in runners:
			var other := other_node as PlanetRunner
			if other != bot and other.is_active_in_field() \
					and other.global_position.distance_to(bot.global_position) <= bot_trigger_radius:
				use_sprint(civ.id)
				break


## Quem dirige o corredor é um BotSteering? (o jogador humano nunca é; no simulador de equilíbrio, sim.)
func _is_bot(runner: PlanetRunner) -> bool:
	return runner.get_node_or_null("Steering") is BotSteering


# Bot: usa a habilidade do bioma dele por regra simples (ver DD-183, 3); sem alvo/sem o que curar use_ability já recusa.
func _tick_bot_abilities() -> void:
	for node in get_tree().get_nodes_in_group("runners"):
		var bot := node as PlanetRunner
		var civ := bot.get_node_or_null("Civilization") as Civilization
		if civ == null or not _is_bot(bot) or _ability_cd.has(civ.id) or not bot.is_active_in_field():
			continue
		var kind := ability_kind(civ.id)
		var health := bot.get_node_or_null("Health") as Health
		if kind == "heal" and (health == null or health.points > health.max_points - heal_points):
			continue   # só cura com um coração inteiro faltando
		if (kind == "frost" or kind == "trick") and _rivals_within(bot, bot_danger_radius, true).is_empty():
			continue   # só se protege/manobra com rival por perto
		use_ability(civ.id)


func _on_match_started() -> void:
	_reset()
	for node in get_tree().get_nodes_in_group("runners"):   # a 1ª carga fica pronta `ability_cooldown` depois da largada
		var civ := node.get_node_or_null("Civilization") as Civilization
		if civ != null:
			_ability_cd[civ.id] = ability_cooldown
			EventBus.ability_charging.emit(civ.id, ability_cooldown, ability_kind(civ.id))


func _reset() -> void:
	for id in _running.keys():
		_stop(id)
	for key in _timed.keys():
		_undo(key)
	_cooldowns.clear()
	_ability_cd.clear()
	_kinds.clear()
