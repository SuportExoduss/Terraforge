extends SceneTree
## Teste de fumaça do Passo 55 (sensibilidade do giro, UI-006): o ajuste "turn" começa em 100% (controle no meio),
## vai de 50% a 150%, multiplica a direção do jogador (teclado e toque) sem passar de ±1, e a tela de configurações
## tem o controle GIRO ligado a ele.
## Uso: godot_console --headless --path . -s res://tools/smoke_turn_sensitivity.gd

const TEST_PROFILE := "user://profile_smoke_turn.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		Input.action_release("ui_right")
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	var settings = load("res://scripts/core/settings.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# Padrão 100% e extremos 50% / 150%; fora da faixa é limitado
	if not _check(is_equal_approx(settings.turn_gain(), 1.0), "padrão: ganho 1,0 (%s)" % settings.turn_gain()): return
	settings.set_value("turn", 0.0)
	if not _check(is_equal_approx(settings.turn_gain(), 0.5), "controle em 0: ganho 0,5"): return
	settings.set_value("turn", 1.0)
	if not _check(is_equal_approx(settings.turn_gain(), 1.5), "controle em 1: ganho 1,5"): return
	settings.set_value("turn", 7.0)
	if not _check(is_equal_approx(settings.turn_gain(), 1.5), "acima do máximo é limitado a 1,5"): return

	# O motorista do jogador multiplica o giro e nunca passa de ±1
	var steering: Node = load("res://scripts/gameplay/player_steering.gd").new()
	root.add_child(steering)
	Input.action_press("ui_right", 0.6)
	settings.set_value("turn", 0.5)
	if not _check(is_equal_approx(steering.get_steer(), 0.6), "100%%: 0,6 vira 0,6 (%s)" % steering.get_steer()): return
	settings.set_value("turn", 0.0)
	if not _check(is_equal_approx(steering.get_steer(), 0.3), "50%%: 0,6 vira 0,3 (%s)" % steering.get_steer()): return
	settings.set_value("turn", 1.0)
	if not _check(is_equal_approx(steering.get_steer(), 0.9), "150%%: 0,6 vira 0,9 (%s)" % steering.get_steer()): return
	Input.action_press("ui_right", 1.0)
	if not _check(is_equal_approx(steering.get_steer(), 1.0), "150%%: giro total fica em 1 (%s)" % steering.get_steer()): return
	Input.action_release("ui_right")
	if not _check(is_equal_approx(steering.get_steer(), 0.0), "sem tecla: 0"): return

	# Toque: o analógico também é multiplicado (e limitado)
	steering._tracking = true
	TouchSteering.set_value(-0.5, Vector2.ZERO)
	if not _check(is_equal_approx(steering.get_steer(), -0.75), "toque -0,5 a 150%%: -0,75 (%s)" % steering.get_steer()): return
	TouchSteering.set_value(-1.0, Vector2.ZERO)
	if not _check(is_equal_approx(steering.get_steer(), -1.0), "toque total a 150%%: -1 (%s)" % steering.get_steer()): return
	steering._tracking = false
	TouchSteering.clear()
	steering.free()

	# A tela de configurações tem o controle GIRO ligado ao ajuste e salva ao soltar
	settings.set_value("turn", 0.5)
	var panel: Control = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await process_frame
	var slider: HSlider = panel.find_child("Turn", true, false)
	if not _check(slider != null and is_equal_approx(slider.value, 0.5), "a tela tem o controle GIRO no meio"): return
	slider.value = 0.2
	if not _check(is_equal_approx(settings.turn_gain(), 0.7), "mexer no controle muda o ganho (%s)" % settings.turn_gain()): return
	slider.drag_ended.emit(true)
	profile.load_data()   # relê do disco
	if not _check(is_equal_approx(settings.turn_gain(), 0.7), "o ganho fica salvo no perfil (%s)" % settings.turn_gain()): return

	panel.free()
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_turn_sensitivity")
	quit(0)
