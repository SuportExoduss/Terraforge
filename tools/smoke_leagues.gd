extends SceneTree
## Teste de fumaça do Passo 122 (ligas, DD-162): faixas Bronze..Lenda sobre a Habilidade, pontos para a próxima liga, linha da
## tela de resultados (PROMOVIDO / caiu), liga no PERFIL (com a cor) e no menu.
## Uso: godot_console --headless --path . -s res://tools/smoke_leagues.gd

const TEST_PROFILE := "user://profile_smoke_leagues.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var leagues = load("res://scripts/core/leagues.gd")
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# Faixas (limites inclusivos no começo da liga)
	var table := {0: "Bronze", 1000: "Bronze", 1099: "Bronze", 1100: "Prata", 1299: "Prata", 1300: "Ouro", 1549: "Ouro",
			1550: "Platina", 1799: "Platina", 1800: "Diamante", 2099: "Diamante", 2100: "Lenda", 9999: "Lenda"}
	for r: int in table:
		if not _check(leagues.name_of(r) == table[r], "habilidade %d = %s (veio %s)" % [r, table[r], leagues.name_of(r)]): return
	if not _check(profile.defaults()["rating"] == 1000 and leagues.name_of(profile.RATING_START) == "Bronze", "perfil novo é Bronze"): return
	if not _check(leagues.to_next(1000) == 100 and leagues.to_next(1099) == 1 and leagues.to_next(2100) == 0, "pontos para a próxima liga"): return
	if not _check(absf(leagues.progress(1000) - 1000.0 / 1100.0) < 0.001 and leagues.progress(1100) == 0.0 and leagues.progress(5000) == 1.0, "progresso na faixa"): return
	if not _check(leagues.color_of(0) != leagues.color_of(2100), "cada liga tem sua cor"): return

	# Linha dos resultados
	var win: String = leagues.result_line(1000, 1025)
	if not _check(win.begins_with("Habilidade 1025 (+25)") and win.contains("Bronze") and win.contains("Faltam 75 para Prata"), "vitória sem trocar de liga: %s" % win): return
	var up: String = leagues.result_line(1090, 1115)
	if not _check(up.contains("PROMOVIDO") and up.contains("Prata"), "promoção: %s" % up): return
	var down: String = leagues.result_line(1105, 1090)
	if not _check(down.contains("Caiu") and down.contains("Bronze") and down.contains("−15"), "queda: %s" % down): return
	var top: String = leagues.result_line(2100, 2125)
	if not _check(top.contains("Lenda") and not top.contains("Faltam"), "última liga não tem próxima: %s" % top): return
	var flat: String = leagues.result_line(1000, 1000)
	if not _check(flat.begins_with("Habilidade 1000 (+0)"), "3º lugar não muda: %s" % flat): return

	# Tela PERFIL: liga + pontos, na cor da liga
	profile.data["rating"] = 1234
	var screen = load("res://scripts/ui/profile_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var label = screen.find_child("Rating", true, false)
	if not _check(label != null and label.text == "Liga Prata  ·  1234", "perfil mostra a liga (veio %s)" % (label.text if label != null else "nada")): return
	if not _check(label.get_theme_color("font_color") == leagues.color_of(1234), "perfil usa a cor da liga"): return
	screen.queue_free()

	# Menu: a liga entra na linha do perfil
	profile.data["rating"] = 1600
	profile.save()   # o menu relê o perfil do disco
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	if not _check(menu.get_node("Box/Profile").text.contains("Liga Platina"), "menu mostra a liga (veio %s)" % menu.get_node("Box/Profile").text): return
	menu.queue_free()

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_leagues")
	quit(0)
