extends SceneTree
## Teste de fumaça do Passo 153 (DD-192): quem dirige o corredor decide se o SkillSystem joga por ele. O jogador humano NUNCA usa sprint/habilidade
## sozinho; o mesmo corredor, com um BotSteering no volante (simulador de equilíbrio, tools/sim_balance.gd), usa pela regra dos bots.
## Uso: godot_console --headless --path . -s res://tools/smoke_bot_player.gd

var _match: Node
var _bus: Node
var _time := 0.0
var _sprints: Array = []
var _abilities: Array = []


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.sprint_used.connect(func(id, _cooldown): _sprints.append(id))
	_bus.ability_used.connect(func(id, kind): _abilities.append([id, kind]))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _wait(seconds: float) -> void:
	var end := _time + seconds
	while _time < end:
		await process_frame


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var skills: Node = _match.get_node("Skills")
	var player: Node3D = _match.get_node("Main/Runner")
	var rival: Node3D = _match.get_node("Main/Runner2")
	for r in [player, rival]:
		r.set_process(false)   # ninguém anda sozinho: o teste põe cada um no lugar
	skills.bots_sprint = true
	skills._ability_cd.clear()
	skills._cooldowns.clear()
	skills._kinds[1] = "frost"   # a Armadura de Gelo só sai com rival por perto (regra dos bots)
	skills._kinds[2] = "frost"
	player._aboard_ship = false
	rival._aboard_ship = false
	rival.teleport_to(player.global_position + player.global_basis.x * 5.0)   # a 5 u: dentro do raio do sprint (10) e do perigo (20)

	# a. Humano no volante: o SkillSystem não joga por ele (o rival bot, sim)
	if not _check(not skills._is_bot(player) and skills._is_bot(rival), "o jogador humano não é bot; o rival é"): return
	await _wait(0.5)
	if not _check(not _sprints.has(1) and not _abilities.has([1, "frost"]), "humano: sem sprint nem habilidade automáticos (%s %s)" % [_sprints, _abilities]): return
	if not _check(_sprints.has(2) and _abilities.has([2, "frost"]), "o rival bot, com o jogador por perto, usa sprint e Armadura (%s %s)" % [_sprints, _abilities]): return

	# b. Mesmo corredor com BotSteering: passa a jogar pela regra dos bots
	player.use_steering(load("res://scripts/ai/bot_steering.gd").new())
	rival.teleport_to(player.global_position + player.global_basis.x * 5.0)   # o rival fugiu no sprint: volta para perto
	if not _check(skills._is_bot(player), "com BotSteering o jogador conta como bot"): return
	await _wait(0.5)
	if not _check(_sprints.has(1) and _abilities.has([1, "frost"]), "jogador-bot usa sprint e Armadura com rival por perto (%s %s)" % [_sprints, _abilities]): return
	print("OK")
	quit(0)
