extends SceneTree
## Teste de fumaça do Passo 42 (tela de perfil): mostra nível, barra de XP entre o início do nível e o próximo, os
## totais acumulados e a lista de conquistas (as feitas em destaque, as outras apagadas). Só lê o perfil.
## Uso: godot_console --headless --path . -s res://tools/smoke_profile_screen.gd

const TEST_PROFILE := "user://profile_smoke_profscreen.json"


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
	var ach = load("res://scripts/core/achievements.gd")
	var screen_script = load("res://scripts/ui/profile_screen.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# início de cada nível bate com Profile.level
	for lvl in range(1, 7):
		var start: int = screen_script.level_start(lvl)
		if not _check(profile.level(start) == lvl, "nível %d começa em %d XP" % [lvl, start]): return
		if lvl > 1 and not _check(profile.level(start - 1) == lvl - 1, "um XP antes ainda é o nível %d" % (lvl - 1)): return

	# perfil de exemplo: 250 XP = nível 2 (100..400), uma conquista feita
	var first_id: String = ach.LIST[0][0]
	profile.data["xp"] = 250
	profile.data["coins"] = 42
	profile.data["matches"] = 7
	profile.data["wins"] = 3
	profile.data["best_percent"] = 0.37
	profile.data["loops"] = 11
	profile.data["cuts"] = 5
	profile.data["kills"] = 2
	profile.data["achievements"] = {first_id: true}
	var screen = screen_script.new()
	root.add_child(screen)
	await process_frame

	var level_label = screen.find_child("Level", true, false)
	var bar = screen.find_child("XpBar", true, false)
	if not _check(level_label != null and level_label.text.contains("2"), "mostra o nível 2"): return
	if not _check(bar != null and bar.min_value == 100.0 and bar.max_value == 400.0 and bar.value == 250.0, "barra de XP 100..400 em 250"): return
	var totals: String = screen.find_child("Totals", true, false).text
	if not _check(totals.contains("42") and totals.contains("7") and totals.contains("3") and totals.contains("37"), "totais: moedas, partidas, vitórias, melhor %"): return
	var totals2: String = screen.find_child("Totals2", true, false).text
	if not _check(totals2.contains("11") and totals2.contains("5") and totals2.contains("2"), "totais: áreas, cortes, eliminações"): return
	var title: String = screen.find_child("AchievementsTitle", true, false).text
	if not _check(title.contains("1/%d" % ach.LIST.size()), "contagem de conquistas 1/N"): return

	# conquistas: a feita em destaque, as outras apagadas
	var done = screen.find_child("A_" + first_id, true, false)
	if not _check(done != null and done.text.begins_with("●"), "conquista feita marcada"): return
	if not _check(done.modulate.a == 1.0, "conquista feita em destaque"): return
	var other_id: String = ach.LIST[1][0]
	var locked = screen.find_child("A_" + other_id, true, false)
	if not _check(locked != null and locked.text.begins_with("○"), "conquista não feita vazia"): return
	if not _check(locked.modulate.a < 0.6, "conquista não feita apagada"): return
	var rows: int = screen.find_child("Achievements", true, false).get_child_count()
	if not _check(rows == ach.LIST.size(), "uma linha por conquista"): return

	# o perfil não foi alterado pela tela
	if not _check(int(profile.data["xp"]) == 250 and int(profile.data["coins"]) == 42, "tela só lê o perfil"): return

	screen.queue_free()

	# Menu: o botão PERFIL abre a tela e VOLTAR a fecha
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var dock_button = menu.get_node_or_null("Box/Dock/Profile")
	if not _check(dock_button != null, "menu tem o botão PERFIL"): return
	dock_button.pressed.emit()
	await process_frame
	var opened = menu.get_node_or_null("Screen")
	if not _check(opened != null and opened.title_text == "PERFIL", "o botão abre o perfil"): return
	opened.back.pressed.emit()
	await process_frame
	await process_frame
	if not _check(menu.get_node_or_null("Screen") == null, "VOLTAR fecha o perfil"): return
	menu.queue_free()

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_profile_screen")
	quit(0)
