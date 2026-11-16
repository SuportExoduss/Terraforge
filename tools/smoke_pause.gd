extends SceneTree
## Teste de fumaça do Passo 127 (DD-167): PAUSA da partida. (1) o botão "II" do HUD existe, tem >= 48 px e fica fora do
## minimapa; (2) pedir a pausa congela de verdade (o relógio da partida não anda) e solta o analógico; (3) ESC fecha
## a camada mais interna (confirmação -> configurações -> pausa) e só depois retoma; (4) CONFIGURAÇÕES abre o painel do
## menu e o VOLTAR dele volta à pausa; (5) o tempo parado não gasta o bônus da ficha; (6) do fim do tempo em diante não
## abre; (7) SAIR confirma, destrava a árvore e NÃO paga a partida; (8) liberar a cena com a pausa aberta destrava.
## Uso: godot_console --headless --path . --fixed-fps 60 -s res://tools/smoke_pause.gd

var _bus: Node
var _failed := false


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _initialize() -> void:
	_run()


func _esc() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	_bus = root.get_node("EventBus")
	var services: Node = root.get_node("Services")
	var match_scene: Node = load("res://scenes/match.tscn").instantiate()
	match_scene.get_node("MatchSetup").skip_ceremony = true
	match_scene.get_node("MatchSetup").bot_count = 0
	match_scene.get_node("Meteors").min_seconds_between = 100000.0
	match_scene.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(match_scene)
	await _bus.match_started
	await _frames(5)
	var pause: Node = match_scene.get_node_or_null("Pause")
	var hud: Node = match_scene.get_node("Hud")
	var timer: Node = match_scene.get_node("MatchTimer")
	_check(pause != null, "a partida deve ter o painel de pausa (nó Pause)")
	_check(not paused and not pause.is_open, "a partida começa sem pausa")

	# 1. Botão II
	var button := hud.get_node_or_null("Root/PauseButton") as Button
	_check(button != null, "o HUD deve ter o botão II (PauseButton)")
	var rect := button.get_global_rect()
	var view := root.get_visible_rect().size
	_check(rect.size.x >= 48.0 and rect.size.y >= 48.0, "o botão II deve caber um dedo (>= 48 px): %s" % rect.size)
	_check(rect.position.x >= 0.0 and rect.end.x <= view.x and rect.position.y >= 0.0 and rect.end.y <= view.y, "o botão II fica dentro da tela: %s em %s" % [rect, view])
	var minimap := hud.get_node("Minimap") as Control
	_check(not rect.intersects(minimap.get_global_rect()), "o botão II não pode cobrir o minimapa")
	_check(button.focus_mode == Control.FOCUS_NONE, "ESPAÇO/ENTER não podem acionar o botão II por foco")

	# 2. Pedir a pausa congela
	TouchSteering.begin(Vector2(100.0, 100.0))
	button.pressed.emit()   # o toque no botão faz o mesmo caminho do ESC
	_check(pause.is_open and paused and pause.visible, "o botão II abre a pausa e congela a árvore")
	_check(not TouchSteering.is_active, "abrir a pausa solta o analógico")
	var left: float = timer._remaining
	await _frames(30)
	_check(is_equal_approx(timer._remaining, left), "com a pausa aberta o relógio da partida não anda (%.3f -> %.3f)" % [left, timer._remaining])
	_check(pause._main.visible and not pause._confirm.visible, "a pausa abre no menu principal")
	for name in ["Resume", "Settings", "Quit"]:
		var b := pause._main.get_node(name) as Button
		_check(b.size.y >= 44.0, "botão %s com altura de dedo (%.0f)" % [name, b.size.y])

	# 3. Camadas do ESC
	pause._main.get_node("Quit").pressed.emit()
	_check(pause._confirm.visible and not pause._main.visible, "SAIR DA PARTIDA pede confirmação")
	pause._unhandled_input(_esc())
	_check(pause.is_open and pause._main.visible, "ESC na confirmação volta ao menu principal (continua pausado)")

	# 4. Configurações
	pause._main.get_node("Settings").pressed.emit()
	await process_frame
	_check(pause._settings != null, "CONFIGURAÇÕES abre o painel do menu")
	var back := pause._settings.find_child("Back", true, false) as Button
	_check(back != null and back.size.y >= 44.0, "o painel de configurações tem o VOLTAR com altura de dedo")
	back.pressed.emit()
	await _frames(2)
	_check(pause._settings == null and pause.is_open and pause._main.visible, "VOLTAR das configurações devolve à pausa")
	pause._main.get_node("Settings").pressed.emit()
	await process_frame
	pause._unhandled_input(_esc())
	await _frames(2)
	_check(pause._settings == null and pause.is_open, "ESC nas configurações fecha só elas")

	# 5. O tempo parado não gasta o bônus da ficha
	_bus.bonus_activated.emit(load("res://scripts/core/civilization.gd").PLAYER_ID, "VELOCIDADE", 10.0)
	var until_before: int = hud._bonus_until["VELOCIDADE"]["until_ms"]
	pause.close()
	_check(not paused and not pause.visible, "CONTINUAR (close) destrava a árvore")
	pause.open()
	OS.delay_msec(300)   # tempo de parede: o relógio dos bônus da HUD é de parede (com --fixed-fps um timer da árvore não serve)
	pause._unhandled_input(_esc())   # ESC no menu principal retoma
	_check(not pause.is_open and not paused, "ESC no menu principal retoma a partida")
	_check(hud._bonus_until["VELOCIDADE"]["until_ms"] - until_before >= 250, "o bônus ganha de volta o tempo da pausa (%d ms)" % (hud._bonus_until["VELOCIDADE"]["until_ms"] - until_before))
	left = timer._remaining
	await _frames(30)
	_check(timer._remaining < left, "depois de retomar o relógio volta a andar")
	pause.back()   # o botão voltar do Android sem pausa aberta abre a pausa
	_check(pause.is_open, "back() sem pausa abre a pausa")
	pause.back()
	_check(not pause.is_open, "back() com a pausa aberta retoma")

	# 6. Do fim do tempo em diante não abre
	var flow = services.flow
	var state_before: int = flow.state
	flow.state = flow.State.TIME_UP
	pause.open()
	_check(not pause.is_open and not paused, "no pós-jogo a pausa não abre")
	flow.state = state_before

	# 7. Sair: confirma, destrava, não paga a partida
	var profile = load("res://scripts/core/profile.gd")   # load(): `Profile` direto compilaria antes dos autoloads
	var matches_before := int(profile.data.get("matches", 0))
	pause.open()
	pause._main.get_node("Quit").pressed.emit()
	pause._confirm.get_node("Leave").pressed.emit()
	await _frames(3)
	_check(not paused, "SAIR destrava a árvore")
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn", "SAIR leva ao menu (%s)" % [current_scene.scene_file_path if current_scene != null else "nada"])
	_check(int(profile.data.get("matches", 0)) == matches_before, "sair no meio não conta partida")
	_check(flow.state < flow.State.TALLY, "sair não passa pela apuração (que pagaria XP)")

	# 8. Cena liberada com a pausa aberta: a árvore não pode ficar parada
	pause.open()
	_check(paused, "pausa aberta de novo")
	match_scene.queue_free()
	await _frames(5)
	_check(not paused, "liberar a partida com a pausa aberta destrava a árvore")

	if not _failed:
		print("OK")
		quit(0)
