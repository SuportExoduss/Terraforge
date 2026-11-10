extends SceneTree
## Teste de fumaça do Passo 8 (SYS-005 Bônus): (1) o pedido de queda espalha N cristais ao redor do ponto;
## (2) Recuperação cura, Vida Extra acrescenta 1 coração e respeita o teto, Velocidade acelera e depois volta ao
## normal, Congelamento freia só o rival próximo, Escudo bloqueia dano por um tempo; (3) cristal esquecido some. Uso: godot_console --headless --path . -s res://tools/smoke_bonus.gd

var _match: Node
var _bus: Node
const SPEED := 0   # = BonusSystem.Kind (a classe não é citada: no modo -s ela compilaria antes dos autoloads)
const HEAL := 1
const EXTRA_LIFE := 2
const FREEZE := 3
const SHIELD := 4

var _bonuses: Node
var _runner: Node3D
var _health: Node
var _time := 0.0
var _activations: Array = []
var _last_max := 0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1   # o rival do teste de Congelamento (fica parado)
	_match.get_node("Meteors").min_seconds_between = 100000.0   # sem meteoro atrapalhando
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.bonus_activated.connect(func(id, kind, seconds): _activations.append([id, kind, seconds]))
	_bus.health_changed.connect(func(id, _p, max_points): if id == 1: _last_max = max_points)
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


func _drop_on_runner(kind: int) -> void:
	_bonuses._spawn(_runner.global_position, _runner.global_basis.y, kind)


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	_bonuses = _match.get_node("Bonuses")
	_runner = _match.get_node("Main/Runner")
	_health = _match.get_node("Main/Runner/Health")
	_runner.set_process(false)   # parado: os cristais caem a poucos passos, a coleta é por proximidade
	_match.get_node("Main/Runner2").set_process(false)

	# 1. Queda: 3 cristais espalhados a ~scatter_radius do centro, ninguém por perto
	var planet: Node = root.get_node("Services").planet
	var away: Vector3 = (_runner.global_position + _runner.global_basis.x * 60.0 - planet.center).normalized()
	var center: Vector3 = planet.center + away * planet.get_surface_radius(away)   # ponto NO chão, como o do meteoro
	_bus.bonus_drop_requested.emit(center, 3)
	var crystals := get_nodes_in_group("bonus_pickups")
	if not _check(crystals.size() == 3, "3 cristais deveriam nascer (%d)" % crystals.size()): return
	for crystal in crystals:
		var d: float = (crystal as Node3D).global_position.distance_to(center)
		if not _check(d > 3.0 and d < 12.0, "cristal fora do círculo de queda (%.1f)" % d): return
	for crystal in crystals:   # limpa: o teste dos efeitos exige cena vazia
		crystal.queue_free()
	_bonuses._pickups.clear()

	# 2a. Recuperação
	_health.take_damage(8)
	_drop_on_runner(HEAL)
	await process_frame
	await process_frame
	if not _check(_health.points == 14, "Recuperação: 8 + 6 = 14 (%d)" % _health.points): return
	if not _check(_activations.size() == 1 and _activations[0] == [1, "RECUPERAÇÃO", 0.0], "sinal da Recuperação: %s" % [_activations]): return
	if not _check(get_nodes_in_group("bonus_pickups").is_empty(), "o cristal deveria sumir ao ser pego"): return

	# 2b. Vida Extra: +1 coração, uma vez só (teto)
	_health.heal(10)
	_drop_on_runner(EXTRA_LIFE)
	await process_frame
	await process_frame
	if not _check(_health.points == 20 and _health.max_points == 20 and _last_max == 20, "Vida Extra: 20/20 (%d/%d, hud %d)" % [_health.points, _health.max_points, _last_max]): return
	_drop_on_runner(EXTRA_LIFE)
	await process_frame
	await process_frame
	if not _check(_health.max_points == 20, "teto de 1 coração extra (%d)" % _health.max_points): return

	# 2c. Velocidade: acelera e depois volta ao normal
	_bonuses.speed_seconds = 0.4
	_drop_on_runner(SPEED)
	await process_frame
	await process_frame
	_bonuses.use_next(1)   # Passo 59: esse tipo vai para o estoque; o efeito começa ao usar
	if not _check(absf(_runner.speed_multiplier - 1.4) < 0.001, "Velocidade x1,4 (%.2f)" % _runner.speed_multiplier): return
	await create_timer(0.7).timeout
	if not _check(_runner.speed_multiplier == 1.0, "a velocidade deveria voltar ao normal (%.2f)" % _runner.speed_multiplier): return

	# 2d. Congelamento: o adversário PERTO fica lento, o LONGE e quem pegou não; depois volta ao normal
	var rival: Node3D = _match.get_node("Main/Runner2")
	var near_dir: Vector3 = (_runner.global_position + _runner.global_basis.x * 10.0 - planet.center).normalized()
	rival.set_process(false)
	rival.teleport_to(planet.center + near_dir * planet.get_surface_radius(near_dir))
	_activations.clear()
	_bonuses.freeze_seconds = 0.4
	_drop_on_runner(FREEZE)
	await process_frame
	await process_frame
	_bonuses.use_next(1)   # Passo 59: esse tipo vai para o estoque; o efeito começa ao usar
	if not _check(rival.freeze_multiplier == 0.5 and _runner.freeze_multiplier == 1.0, "Congelamento: rival 0,5 e quem pegou 1,0 (%.2f / %.2f)" % [rival.freeze_multiplier, _runner.freeze_multiplier]): return
	if not _check(_activations.has([2, "CONGELADO", 0.4]) and _activations.has([1, "CONGELAMENTO", 0.4]), "sinais do Congelamento: %s" % [_activations]): return
	await create_timer(0.7).timeout
	if not _check(rival.freeze_multiplier == 1.0, "o rival deveria voltar ao normal (%.2f)" % rival.freeze_multiplier): return
	var far_dir: Vector3 = (_runner.global_position - _runner.global_basis.x * 80.0 - planet.center).normalized()
	rival.teleport_to(planet.center + far_dir * planet.get_surface_radius(far_dir))
	_drop_on_runner(FREEZE)
	await process_frame
	await process_frame
	_bonuses.use_next(1)   # Passo 59: esse tipo vai para o estoque; o efeito começa ao usar
	if not _check(rival.freeze_multiplier == 1.0, "rival longe não congela (%.2f)" % rival.freeze_multiplier): return

	# 2e. Escudo Temporal: dano de pontos não passa; acabou o tempo, volta a ferir
	_health.heal(20)
	_bonuses.shield_seconds = 0.4
	_drop_on_runner(SHIELD)
	await process_frame
	await process_frame
	_bonuses.use_next(1)   # Passo 59: esse tipo vai para o estoque; o efeito começa ao usar
	_health.take_damage(4)
	if not _check(_health.points == _health.max_points, "Escudo: sem dano (%d)" % _health.points): return
	await create_timer(0.7).timeout
	_health.take_damage(4)
	if not _check(_health.points == _health.max_points - 4, "sem o Escudo volta a ferir (%d)" % _health.points): return

	# 3. Cristal esquecido some
	_bonuses.lifetime_seconds = 0.3
	_bonuses._spawn(_runner.global_position + _runner.global_basis.x * 60.0, _runner.global_basis.y, HEAL)
	if not _check(get_nodes_in_group("bonus_pickups").size() == 1, "cristal longe deveria ficar no chão"): return
	await create_timer(0.6).timeout
	if not _check(get_nodes_in_group("bonus_pickups").is_empty(), "o cristal deveria expirar"): return
	print("OK")
	quit(0)
