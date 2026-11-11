extends SceneTree
## Teste de fumaça do Passo 59 (Cap.03 P08 USO): Velocidade, Congelamento e Escudo vão para o estoque (limite 3, o mais
## antigo sai primeiro); Recuperação continua automática; estoque cheio deixa o cristal no chão; o jogador só usa
## quando quer, o bot usa sozinho depois de bot_use_delay. Uso: godot_console --headless --path . -s res://tools/smoke_bonus_stock.gd

const SPEED := 0   # = BonusSystem.Kind (a classe não é citada: no modo -s ela compilaria antes dos autoloads)
const HEAL := 1
const FREEZE := 3
const SHIELD := 4

var _match: Node
var _bus: Node
var _bonuses: Node
var _runner: Node3D
var _health: Node
var _time := 0.0
var _signals: Array = []


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.bonus_stock_changed.connect(func(id, kinds): _signals.append([id, kinds]))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _drop(on: Node3D, kind: int) -> void:
	_bonuses._spawn(on.global_position, on.global_basis.y, kind)
	await process_frame
	await process_frame


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	_bonuses = _match.get_node("Bonuses")
	_runner = _match.get_node("Main/Runner")
	_health = _match.get_node("Main/Runner/Health")
	var rival: Node3D = _match.get_node("Main/Runner2")
	_runner.set_process(false)
	rival.set_process(false)
	_bonuses.bot_use_delay = 0.3

	# 1. Velocidade vai para o estoque: cristal some, efeito NÃO liga, sinal avisa
	await _drop(_runner, SPEED)
	if not _check(_runner.speed_multiplier == 1.0, "Velocidade não deve ligar ao pegar (%.2f)" % _runner.speed_multiplier): return
	if not _check(_bonuses.stock_of(1) == [SPEED], "estoque deveria ter [SPEED]: %s" % [_bonuses.stock_of(1)]): return
	if not _check(get_nodes_in_group("bonus_pickups").is_empty(), "o cristal guardado deveria sumir do chão"): return
	if not _check(_signals.back() == [1, ["VELOCIDADE"]], "sinal do estoque: %s" % [_signals.back()]): return

	# 2. Recuperação segue automática mesmo com estoque
	_health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	_health.take_damage(8)
	await _drop(_runner, HEAL)
	if not _check(_health.points == 14, "Recuperação automática: 8 + 6 = 14 (%d)" % _health.points): return
	if not _check(_bonuses.stock_of(1) == [SPEED], "Recuperação não vai para o estoque"): return

	# 3. Enche o estoque; o jogador NÃO usa sozinho (bot_use_delay só vale para bots)
	await _drop(_runner, FREEZE)
	await _drop(_runner, SHIELD)
	if not _check(_bonuses.stock_of(1) == [SPEED, FREEZE, SHIELD], "estoque cheio: %s" % [_bonuses.stock_of(1)]): return
	await create_timer(0.6).timeout
	if not _check(_bonuses.stock_of(1).size() == 3, "o jogador não usa o estoque sozinho"): return

	# 4. Estoque cheio: o 4º cristal fica no chão; Recuperação ainda é pega
	await _drop(_runner, SPEED)
	if not _check(_bonuses.stock_of(1).size() == 3, "o 4º não cabe (%d)" % _bonuses.stock_of(1).size()): return
	if not _check(get_nodes_in_group("bonus_pickups").size() == 1, "o 4º cristal deveria ficar no chão"): return
	_health.take_damage(4)
	await _drop(_runner, HEAL)
	if not _check(_health.points == 16, "Recuperação com estoque cheio: 10 + 6 = 16 (%d)" % _health.points): return
	if not _check(get_nodes_in_group("bonus_pickups").size() == 1, "só o cristal guardável fica no chão"): return

	# 5. Uso em ordem (o mais antigo primeiro); o cristal do chão entra assim que sobra vaga
	_bonuses.speed_seconds = 5.0
	if not _check(_bonuses.use_next(1), "use_next deveria usar o estoque"): return
	if not _check(absf(_runner.speed_multiplier - 1.4) < 0.001, "Velocidade x1,4 ao usar (%.2f)" % _runner.speed_multiplier): return
	await process_frame
	await process_frame
	if not _check(_bonuses.stock_of(1) == [FREEZE, SHIELD, SPEED], "ordem do estoque: %s" % [_bonuses.stock_of(1)]): return
	if not _check(get_nodes_in_group("bonus_pickups").is_empty(), "o cristal do chão deveria ter entrado"): return
	_bonuses.use_next(1)
	_bonuses.use_next(1)
	if not _check(_health.shield_left > 0.0, "Escudo ligou ao usar"): return
	if not _check(_bonuses.use_next(1), "último item"): return
	if not _check(not _bonuses.use_next(1) and _bonuses.stock_of(1).is_empty(), "estoque vazio: use_next devolve false"): return

	# 6. O bot usa sozinho depois de bot_use_delay
	var rival_health: Node = _match.get_node("Main/Runner2/Health")
	rival_health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	await _drop(rival, SHIELD)
	if not _check(_bonuses.stock_of(2) == [SHIELD] and rival_health.shield_left == 0.0, "bot guardou o Escudo sem ligar: %s" % [_bonuses.stock_of(2)]): return
	await create_timer(0.7).timeout
	if not _check(_bonuses.stock_of(2).is_empty() and rival_health.shield_left > 0.0, "bot deveria usar o Escudo sozinho"): return

	print("OK: Velocidade/Congelamento/Escudo guardados (limite 3, em ordem); Recuperação automática; bot usa sozinho")
	quit(0)
