extends SceneTree
## Teste de fumaça do Passo 41 (galeria de civilizações): o catálogo diz quem é jogável (só a que tem piso), a escolha
## fica no perfil e recusa as "em breve", a tela mostra uma linha por civilização (as sem arte desabilitadas), e o
## registro de fichas troca a civilização 1 pela escolhida (testado com fichas falsas).
## Uso: godot_console --headless --path . -s res://tools/smoke_civilizations.gd

const TEST_PROFILE := "user://profile_smoke_civs.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _theme(name: String) -> Resource:
	var t = load("res://scripts/world/planet_theme.gd").new()
	t.civilization_name = name
	return t


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	var catalog = load("res://scripts/core/civilization_catalog.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# Catálogo: 6 civilizações, só a 1 (Velho Oeste) tem piso hoje
	if not _check(catalog.count() == 6, "6 civilizações no catálogo"): return
	if not _check(catalog.is_playable(1), "civilização 1 jogável"): return
	if not _check(not catalog.is_playable(2), "civilização 2 ainda em breve"): return
	if not _check(catalog.chosen() == 1, "padrão = civilização 1"): return
	if not _check(not catalog.choose(2), "escolher civilização em breve é recusado"): return
	if not _check(not catalog.choose(0) and not catalog.choose(7), "ids fora da faixa recusados"): return
	if not _check(catalog.choose(1), "escolher a 1 funciona"): return
	# escolha gravada que deixou de ser jogável volta para a 1
	profile.data["civilization"] = 4
	if not _check(catalog.chosen() == 1, "escolha não jogável cai na 1"): return
	profile.data["civilization"] = 1

	# Persistência: o arquivo guarda a escolha
	profile.load_data()
	if not _check(int(profile.data.get("civilization", 0)) == 1, "escolha sobrevive a recarregar o perfil"): return

	# Tela: uma linha por civilização, as sem arte desabilitadas, a escolhida marcada
	var screen = load("res://scripts/ui/civilizations_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var buttons := []
	for i in range(1, 7):
		var b = screen.find_child("Civ%d" % i, true, false)
		if not _check(b != null, "botão Civ%d existe" % i): return
		buttons.append(b)
	if not _check(not buttons[0].disabled and buttons[0].button_pressed, "Civ1 habilitada e marcada"): return
	for i in range(1, 6):
		if not _check(buttons[i].disabled, "Civ%d desabilitada (em breve)" % (i + 1)): return
		if not _check(buttons[i].text.contains("em breve"), "Civ%d avisa 'em breve'" % (i + 1)): return
	if not _check(screen.find_child("Swatch1", true, false) != null, "cor do solo da civilização 1"): return
	# VOLTAR fecha a tela e avisa
	var closed := [false]
	screen.closed.connect(func(): closed[0] = true)
	screen.back.pressed.emit()
	if not _check(closed[0], "VOLTAR emite closed"): return
	screen.queue_free()

	# Registro: a escolhida assume o lugar da 1 (fichas e fatias do atlas trocam, sem tocar no atlas original)
	var registry = load("res://scripts/world/planet_theme_registry.gd").new()
	var themes := [_theme("A"), _theme("B"), _theme("C")]
	registry.civilization_themes.assign(themes)
	var atlas = load("res://scripts/world/ground_atlas.gd").new()
	atlas.slice_of = PackedInt32Array([0, -1, 1])
	atlas.dead_slice_of = PackedInt32Array([0, -1, 1])
	registry.atlas = atlas
	registry.apply_choice(1)
	if not _check(registry.theme_of(1).civilization_name == "A", "escolher 1 não troca nada"): return
	registry.apply_choice(3)
	if not _check(registry.theme_of(1).civilization_name == "C", "civilização 3 assume a posição 1"): return
	if not _check(registry.theme_of(3).civilization_name == "A", "a 1 vai para a posição 3"): return
	if not _check(registry.theme_of(2).civilization_name == "B", "a 2 fica onde estava"): return
	if not _check(registry.atlas.slice_of[0] == 1 and registry.atlas.slice_of[2] == 0, "fatias do atlas trocaram junto"): return
	if not _check(atlas.slice_of[0] == 0, "atlas original intacto"): return
	registry.apply_choice(9)
	if not _check(registry.theme_of(1).civilization_name == "C", "id fora da faixa não mexe"): return
	registry.free()

	# Menu: o botão CIVILIZAÇÕES abre a tela e VOLTAR a fecha
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var dock_button = menu.get_node_or_null("Box/Dock/Civilizations")
	if not _check(dock_button != null, "menu tem o botão CIVILIZAÇÕES"): return
	dock_button.pressed.emit()
	await process_frame
	var opened = menu.get_node_or_null("Screen")
	if not _check(opened != null and opened.title_text == "CIVILIZAÇÕES", "o botão abre a galeria"): return
	opened.back.pressed.emit()
	await process_frame
	await process_frame
	if not _check(menu.get_node_or_null("Screen") == null, "VOLTAR fecha a galeria"): return
	menu.queue_free()

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_civilizations")
	quit(0)
