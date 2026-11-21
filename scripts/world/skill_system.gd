class_name SkillSystem
extends Node
## DD-182 (Passo 143): SPRINT, a corrida rápida para a frente que o jogador aciona (botão da HUD ou SHIFT).
## O corredor anda a `sprint_multiplier` da velocidade por `sprint_seconds` e a carga volta `sprint_cooldown` segundos DEPOIS do
## uso (uma carga só, igual para todos). Só vale com o corredor em campo; a pausa da árvore congela os relógios. O efeito escala
## `move_speed` (e desfaz dividindo), então soma-se por multiplicação ao bônus Velocidade, ao Congelamento e à lentidão dos eventos.
## Fala com o resto só por sinais (sprint_requested entra, sprint_used sai) e pelo grupo "runners".
## Bots arrancam quando há um rival por perto (perseguir ou fugir).
## ponytail: sem estado por corredor além de dois dicionários; o online (comando no protocolo) entra depois.

@export var sprint_multiplier := 1.8
@export var sprint_seconds := 0.8
@export var sprint_cooldown := 3.5
@export var bots_sprint := true
@export var bot_trigger_radius := 10.0   # rival em campo a esta distância (ou menos): o bot arranca

var _running: Dictionary = {}     # id da civilização -> {runner, left}: sprints em curso
var _cooldowns: Dictionary = {}   # id -> segundos que faltam para a próxima carga (sem entrada = pronto)


func _ready() -> void:
	EventBus.sprint_requested.connect(use_sprint)
	EventBus.match_started.connect(_reset)
	EventBus.match_ended.connect(_reset)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SHIFT:
		use_sprint(Civilization.PLAYER_ID)


func _process(delta: float) -> void:
	_tick_running(delta)
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	if bots_sprint:
		_tick_bots()


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
		if civ == null or civ.id == Civilization.PLAYER_ID or _cooldowns.has(civ.id) or not bot.is_active_in_field():
			continue
		for other_node in runners:
			var other := other_node as PlanetRunner
			if other != bot and other.is_active_in_field() \
					and other.global_position.distance_to(bot.global_position) <= bot_trigger_radius:
				use_sprint(civ.id)
				break


func _reset() -> void:
	for id in _running.keys():
		_stop(id)
	_cooldowns.clear()
