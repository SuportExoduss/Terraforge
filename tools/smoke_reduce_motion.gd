extends SceneTree
## Teste de fumaça do Passo 56 (reduzir movimento, UI-006 / Cap.05 P06 acessibilidade): o ajuste começa desligado; ligado,
## o fundo do menu não cria meteoros nem auroras (e apaga a aurora acesa) e a tempestade não dá clarão de relâmpago;
## desligado, tudo volta; a tela de configurações tem o botão REDUZIR MOVIMENTO ligado ao ajuste e o ajuste fica salvo.
## Uso: godot_console --headless --path . -s res://tools/smoke_reduce_motion.gd

const TEST_PROFILE := "user://profile_smoke_reduce.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
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
	if not _check(not settings.reduced_motion(), "padrão: movimento normal"): return

	# Fundo do menu: desligado cria meteoro e aurora; ligado não cria e apaga a aurora acesa
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var back: Node = menu.get_node("Backdrop")
	var meteors: int = back.meteors_spawned
	var auroras: int = back.auroras_shown
	back._meteor_clock = 0.0
	back._aurora_clock = 0.0
	back._process(0.1)
	if not _check(back.meteors_spawned == meteors + 1 and back.auroras_shown == auroras + 1 and back.aurora.visible, "movimento normal: meteoro e aurora aparecem"): return
	settings.set_value("reduce_motion", 1.0)
	if not _check(settings.reduced_motion(), "ligado: reduced_motion() é verdadeiro"): return
	back._meteor_clock = 0.0
	back._aurora_clock = 0.0
	back._process(0.1)
	if not _check(back.meteors_spawned == meteors + 1 and back.auroras_shown == auroras + 1, "reduzido: nenhum meteoro/aurora novo"): return
	if not _check(not back.aurora.visible and back.aurora_strength() == 0.0, "reduzido: a aurora acesa apaga"): return
	settings.set_value("reduce_motion", 0.0)
	back._meteor_clock = 0.0
	back._process(0.1)
	if not _check(back.meteors_spawned == meteors + 2, "desligado de novo: meteoros voltam"): return
	menu.free()

	# Relâmpago: reduzido não dá clarão
	var match_node: Node = load("res://scenes/match.tscn").instantiate()
	match_node.get_node("MatchSetup").skip_ceremony = true
	match_node.get_node("MatchSetup").bot_count = 0
	match_node.get_node("Meteors").min_seconds_between = 100000.0
	match_node.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(match_node)
	await process_frame
	var weather: Node = match_node.get_node("Weather")
	var flashes: int = weather.flashes
	settings.set_value("reduce_motion", 1.0)
	weather.strike()
	if not _check(weather.flashes == flashes, "reduzido: o relâmpago não dá clarão"): return
	settings.set_value("reduce_motion", 0.0)
	weather.strike()
	if not _check(weather.flashes == flashes + 1, "normal: o relâmpago dá clarão"): return
	match_node.queue_free()
	await process_frame

	# Tela de configurações: o botão liga/desliga e salva
	var panel: Control = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await process_frame
	var button: CheckButton = panel.find_child("ReduceMotion", true, false)
	if not _check(button != null and not button.button_pressed, "a tela tem REDUZIR MOVIMENTO desligado"): return
	button.button_pressed = true
	if not _check(settings.reduced_motion(), "ligar o botão liga o ajuste"): return
	profile.load_data()   # relê do disco
	if not _check(settings.reduced_motion(), "o ajuste fica salvo no perfil"): return

	panel.free()
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_reduce_motion")
	quit(0)
