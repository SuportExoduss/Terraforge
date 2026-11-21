extends SceneTree
## Teste de fumaça do Passo 60 (Cap.03 P08 INTERFACE): o botão da HUD mostra o próximo bônus guardado e o contador;
## a tecla E e o toque no botão usam o bônus (outra tecla não); o toque no botão não vira direção; o botão some ao esvaziar.
## Uso: godot_console --headless --path . -s res://tools/smoke_bonus_use.gd

const SPEED := 0   # = BonusSystem.Kind (a classe não é citada: no modo -s ela compilaria antes dos autoloads)
const FREEZE := 3

var _match: Node
var _bus: Node
var _time := 0.0


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
	if _time > 30.0:
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


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var bonuses: Node = _match.get_node("Bonuses")
	var runner: Node3D = _match.get_node("Main/Runner")
	var hud: Node = _match.get_node("Hud")
	var button := hud.find_child("Stock", true, false) as Button
	if not _check(button != null and not button.visible, "o botão do estoque deveria existir e começar escondido"): return
	runner.set_process(false)
	_match.get_node("Main/Runner2").set_process(false)

	# 1. Guardou: botão mostra o próximo e o contador
	bonuses._spawn(runner.global_position, runner.global_basis.y, SPEED)
	await process_frame
	await process_frame
	bonuses._spawn(runner.global_position, runner.global_basis.y, FREEZE)   # um de cada vez: no mesmo quadro o último cristal sai primeiro
	await process_frame
	await process_frame
	if not _check(button.visible and button.text.contains("VELOCIDADE") and button.text.contains("[2]"), "botão: '%s'" % button.text): return

	# 2. Outra tecla e eco do E não usam; E (letra, Passo 159) usa o primeiro (Velocidade)
	hud._unhandled_input(_key(KEY_A))
	hud._unhandled_input(_key(KEY_SPACE))   # o ESPAÇO deixou de ser a tecla do bônus
	hud._unhandled_input(_key(KEY_E, true))
	if not _check(bonuses.stock_of(1).size() == 2 and runner.speed_multiplier == 1.0, "só E (sem eco) deve usar"): return
	hud._unhandled_input(_key(KEY_E))
	if not _check(absf(runner.speed_multiplier - 1.4) < 0.001, "E deveria ligar a Velocidade (%.2f)" % runner.speed_multiplier): return
	if not _check(button.visible and button.text.contains("CONGELAMENTO") and button.text.contains("[1]"), "botão depois: '%s'" % button.text): return

	# 3. Toque no botão: não vira direção enquanto pressionado; ao soltar usa o item e o botão some
	button.button_down.emit()
	if not _check(TouchSteering.is_ui_pointer_held, "o toque no botão não deve virar direção"): return
	button.button_up.emit()
	button.pressed.emit()
	if not _check(not TouchSteering.is_ui_pointer_held, "soltou: o ponteiro volta ao jogo"): return
	if not _check(bonuses.stock_of(1).is_empty() and not button.visible, "estoque vazio: botão some"): return

	# 4. Sem estoque, E não faz nada (e não quebra)
	hud._unhandled_input(_key(KEY_E))
	if not _check(bonuses.stock_of(1).is_empty(), "E sem estoque"): return

	print("OK: botão da HUD mostra próximo+contador; a tecla E e o toque usam o bônus; toque no botão não vira direção")
	quit(0)
