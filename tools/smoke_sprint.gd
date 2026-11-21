extends SceneTree
## Teste de fumaça do Passo 143 (DD-182): SPRINT. (1) SHIFT (sem eco; outra tecla não) liga a corrida ×1,8 e consome a carga;
## (2) durante a recarga, outro SHIFT não faz nada; (3) o corredor anda de fato 1,8× mais (mesmo quadro, com e sem sprint);
## (4) o sprint acaba sozinho (velocidade volta) e a carga volta depois da recarga; (5) fora de campo não vale e não gasta a carga;
## (6) pausa congela o relógio; (7) bot só arranca com rival por perto; (8) fim de partida desfaz tudo;
## (9) o botão da HUD (grande, no canto, segura o toque de direção) liga o sprint, apaga com os segundos da recarga e volta pronto.
## Uso: godot_console --headless --path . -s res://tools/smoke_sprint.gd

var _match: Node
var _bus: Node
var _time := 0.0
var _used: Array = []   # sprint_used(id, cooldown) recebidos


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 40.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _key(code: Key, echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	return ev


## Quanto o corredor anda num quadro de `dt` segundos (posição antes/depois de um _process manual).
func _step(runner: Node3D, dt: float) -> float:
	var before := runner.global_position
	runner._process(dt)
	return runner.global_position.distance_to(before)


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var skills: Node = _match.get_node("Skills")
	var runner: Node3D = _match.get_node("Main/Runner")
	var bot: Node3D = _match.get_node("Main/Runner2")
	var bot_id: int = bot.get_node("Civilization").id
	runner.set_process(false)   # o teste dá os passos na mão (_step) para medir a distância
	bot.set_process(false)
	skills.bots_sprint = false
	skills.sprint_seconds = 0.3
	skills.sprint_cooldown = 1.2
	_bus.sprint_used.connect(func(id, cd): _used.append([id, cd]))
	var base: float = runner.move_speed

	# 1. Pronto no início; outra tecla e o eco do SHIFT não ligam
	if not _check(skills.sprint_ready(1) and not skills.sprint_running(1), "a carga começa pronta"): return
	skills._unhandled_input(_key(KEY_A))
	skills._unhandled_input(_key(KEY_ALT, true))
	if not _check(not skills.sprint_running(1) and _used.is_empty(), "só SHIFT (sem eco) liga o sprint"): return

	# 9a. Botão da HUD: existe, tem tamanho de dedo, está pronto e segura o toque de direção
	var button: Button = _match.get_node("Hud").find_child("SprintButton", true, false)
	if not _check(button != null and button.size.x >= 64.0 and button.size.y >= 64.0 and not button.disabled, "botão do sprint na HUD, grande e pronto"): return
	button.button_down.emit()
	var held: bool = TouchSteering.is_ui_pointer_held
	button.button_up.emit()
	if not _check(held and not TouchSteering.is_ui_pointer_held, "o toque no botão não vira direção"): return

	# 3. Distância: sem sprint x com sprint, o mesmo passo
	var normal := _step(runner, 0.05)
	skills._unhandled_input(_key(KEY_ALT))
	if not _check(skills.sprint_running(1) and not skills.sprint_ready(1), "SHIFT liga o sprint e gasta a carga"): return
	if not _check(absf(runner.move_speed - base * 1.8) < 0.001, "velocidade ×1,8 (%.2f)" % runner.move_speed): return
	if not _check(_used.size() == 1 and _used[0][0] == 1 and absf(_used[0][1] - 1.2) < 0.001, "sprint_used(1, recarga) emitido (%s)" % [_used]): return
	var fast := _step(runner, 0.05)
	if not _check(normal > 0.1 and fast / normal > 1.7 and fast / normal < 1.9, "anda 1,8× mais (%.3f / %.3f)" % [fast, normal]): return

	if not _check(button.disabled and button.text.begins_with("1."), "recarregando: botão apagado com os segundos (%s)" % button.text): return

	# 2. Recarregando: outro SHIFT não faz nada
	skills._unhandled_input(_key(KEY_ALT))
	if not _check(_used.size() == 1 and absf(runner.move_speed - base * 1.8) < 0.001, "durante a recarga, SHIFT não faz nada"): return

	# 4. O sprint acaba sozinho (0,3 s); a carga só volta depois de 1,2 s do uso
	await create_timer(0.5).timeout
	if not _check(not skills.sprint_running(1) and absf(runner.move_speed - base) < 0.001, "o sprint acabou: velocidade volta (%.2f)" % runner.move_speed): return
	if not _check(not skills.sprint_ready(1) and skills.sprint_cooldown_left(1) > 0.0, "ainda recarrega"): return
	await create_timer(1.0).timeout
	if not _check(skills.sprint_ready(1), "passada a recarga, a carga volta"): return
	if not _check(not button.disabled and button.text == "»", "o botão volta pronto (%s)" % button.text): return

	# 5. Fora de campo não vale e não gasta a carga
	runner._aboard_ship = true
	skills._unhandled_input(_key(KEY_ALT))
	if not _check(not skills.sprint_running(1) and skills.sprint_ready(1) and _used.size() == 1, "embarcado: SHIFT não gasta a carga"): return
	runner._aboard_ship = false

	# 6. Pausa congela o relógio: o sprint e a recarga ficam parados
	skills._unhandled_input(_key(KEY_ALT))
	if not _check(skills.sprint_running(1), "sprint ligado de novo"): return
	var left: float = skills.sprint_cooldown_left(1)
	paused = true
	await create_timer(0.6).timeout
	var frozen: bool = skills.sprint_running(1) and absf(skills.sprint_cooldown_left(1) - left) < 0.05
	paused = false
	if not _check(frozen, "com a pausa aberta o relógio do sprint não anda"): return
	await create_timer(0.5).timeout
	if not _check(not skills.sprint_running(1) and absf(runner.move_speed - base) < 0.001, "despausou: o sprint termina"): return

	# 7. Bot: longe de todo mundo não arranca; com um rival por perto, arranca
	skills.bots_sprint = true
	skills.bot_trigger_radius = 10.0
	if not _check(bot.global_position.distance_to(runner.global_position) > 10.0, "pré-condição: o bot começa longe do jogador"): return
	await process_frame
	await process_frame
	if not _check(not skills.sprint_running(bot_id), "bot sem rival por perto não arranca"): return
	var bot_base: float = bot.move_speed
	bot.teleport_to(runner.global_position + runner.global_basis.x * 3.0)
	await process_frame
	await process_frame
	if not _check(skills.sprint_running(bot_id) and absf(bot.move_speed - bot_base * 1.8) < 0.001, "bot com rival a 3 unidades arranca"): return

	# 8. Fim de partida: velocidades voltam e as cargas zeram
	skills._reset()
	if not _check(not skills.sprint_running(bot_id) and absf(bot.move_speed - bot_base) < 0.001 and skills.sprint_ready(1) and skills.sprint_ready(bot_id), "reset desfaz o sprint e zera as cargas"): return

	# 9b. Tocar o botão pede o sprint do jogador
	button.pressed.emit()
	if not _check(skills.sprint_running(1), "tocar o botão liga o sprint do jogador"): return

	print("OK: SHIFT liga o sprint ×1,8 por 0,3 s com recarga; anda 1,8× mais; fora de campo e pausa respeitados; bot arranca com rival por perto")
	quit(0)
