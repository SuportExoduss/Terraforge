extends SceneTree
## Teste de fumaça do Passo 156 (DD-195): CONFIGURAÇÃO DE CONTROLES. (1) Settings: tamanho dos botões 60%–140% (padrão 100%), tecla de cada
## ação (padrão SHIFT / E / ESPAÇO), troca sem duplicar, teclas proibidas recusadas, tudo salvo e restaurável; (2) ControlLayout: o tamanho
## cresce/encolhe com o ajuste, corrige pela densidade do toque e nunca passa da fatia da tela; (3) o painel de Ajustes: controle de tamanho
## com botão de amostra, clique-e-aperte para trocar a tecla, ESC cancela, proibida é ignorada, restaurar; (4) na partida: os botões da HUD
## seguem o tamanho, NÃO se sobrepõem (nem ao minimapa/pausa/bônus) e ficam dentro da tela em várias telas, e SÓ a tecla nova aciona o sprint.
## Uso: godot_console --headless --path . -s res://tools/smoke_controls.gd

var _match: Node
var _bus: Node
var _time := 0.0
var _sprints := 0
var S   # settings.gd (carregado em _run: no modo -s o script compila antes dos autoloads)


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 90.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _reload() -> void:   # grava e relê o perfil: o que fica salvo é o que vale
	Profile.save()
	Profile.data = Profile.defaults()
	Profile.load_data()


func _run() -> void:
	Profile.path = "user://profile_smoke_controls.json"
	Profile.data = Profile.defaults()
	Profile.save()
	S = load("res://scripts/core/settings.gd")
	var L = load("res://scripts/ui/control_layout.gd")

	# 1. Settings
	if not _check(is_equal_approx(S.button_scale(), 1.0), "tamanho padrão = 100%"): return
	if not _check(S.key_for("sprint") == KEY_SHIFT and S.key_for("ability") == KEY_E and S.key_for("bonus") == KEY_SPACE, "teclas padrão SHIFT / E / ESPAÇO"): return
	if not _check(S.key_label("sprint") == "SHIFT" and S.key_label("ability") == "E" and S.key_label("bonus") == "ESPAÇO", "nomes padrão (%s %s %s)" % [S.key_label("sprint"), S.key_label("ability"), S.key_label("bonus")]): return
	S.set_value("btn_size", 0.0)
	if not _check(is_equal_approx(S.button_scale(), 0.6), "tamanho mínimo = 60%"): return
	S.set_value("btn_size", 5.0)
	if not _check(is_equal_approx(S.button_scale(), 1.4), "tamanho máximo = 140% (valor absurdo é cortado)"): return
	_reload()
	if not _check(is_equal_approx(S.button_scale(), 1.4), "o tamanho fica salvo no perfil"): return
	if not _check(S.set_key("sprint", KEY_Q) and S.key_for("sprint") == KEY_Q and S.key_label("sprint") == "Q".to_upper(), "troca o SPRINT para Q"): return
	if not _check(S.set_key("ability", KEY_Q) and S.key_for("ability") == KEY_Q and S.key_for("sprint") == KEY_E, "habilidade pega o Q; o SPRINT, que tinha o Q, fica com o E que era dela"): return
	for blocked in [KEY_ESCAPE, KEY_ENTER, KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_BACK, KEY_NONE]:
		if not _check(not S.set_key("bonus", blocked) and S.key_for("bonus") == KEY_SPACE, "tecla proibida recusada (%d)" % blocked): return
	if not _check(not S.set_key("inexistente", KEY_Z), "ação desconhecida é recusada"): return
	_reload()
	if not _check(S.key_for("sprint") == KEY_E and S.key_for("ability") == KEY_Q and S.key_for("bonus") == KEY_SPACE, "as teclas ficam salvas"): return
	var distinct := {}
	for a: String in S.KEY_ACTIONS:
		distinct[S.key_for(a)] = true
	if not _check(distinct.size() == 3, "três ações, três teclas"): return
	S.reset_controls()
	if not _check(is_equal_approx(S.button_scale(), 1.0) and S.key_for("sprint") == KEY_SHIFT and S.key_for("ability") == KEY_E and S.key_for("bonus") == KEY_SPACE, "restaurar volta ao padrão"): return

	# 2. ControlLayout
	var view := Vector2(960, 540)
	var base := 76.0
	if not _check(is_equal_approx(L.action_size(base, 1.0, view, 1.0, 96.0, false), 76.0), "PC, 100% = 76"): return
	if not _check(is_equal_approx(L.action_size(base, 0.6, view, 1.0, 96.0, false), 45.6) and is_equal_approx(L.action_size(base, 1.4, view, 1.0, 96.0, false), 106.4), "60% = 45,6 e 140% = 106,4"): return
	var dense: float = L.action_size(base, 1.0, Vector2(1168, 540), 2.0, 420.0, true)   # celular 6", 2400x1080
	var wide: float = L.action_size(base, 1.0, Vector2(960, 600), 2.67, 300.0, true)     # tablet 10", 2560x1600
	if not _check(dense > 76.0 and wide < dense, "toque: celular denso fica maior que o tablet (%.1f x %.1f)" % [dense, wide]): return
	if not _check(L.action_size(base, 1.4, Vector2(960, 200), 1.0, 96.0, false) <= 200.0 * L.MAX_HEIGHT_SHARE + 0.01 or L.action_size(base, 1.4, Vector2(960, 200), 1.0, 96.0, false) == L.MIN_SIZE, "tela baixa: o botão não passa da fatia da altura"): return
	if not _check(L.action_size(base, 0.1, view, 1.0, 96.0, false) == L.MIN_SIZE, "nunca menor que o mínimo de dedo"): return

	# 3. Painel de Ajustes
	var panel = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await process_frame
	await process_frame
	var slider := panel.find_child("ButtonSize", true, false) as HSlider
	var sample := panel.find_child("PreviewButton", true, false) as Control
	if not _check(slider != null and sample != null and is_equal_approx(slider.value, 0.5) and is_equal_approx(sample.custom_minimum_size.x, 76.0), "painel: controle de tamanho no padrão com a amostra em 76"): return
	slider.value = 1.0
	if not _check(is_equal_approx(sample.custom_minimum_size.x, 106.4) and is_equal_approx(S.button_scale(), 1.4), "mexer no controle muda a amostra e o ajuste na hora"): return
	var pick := panel.find_child("Key_sprint", true, false).get_node("Pick") as Button
	if not _check(pick.text == "SHIFT", "botão da tecla mostra a atual (%s)" % pick.text): return
	pick.pressed.emit()
	if not _check(pick.text == "APERTE UMA TECLA...", "clicou: espera a tecla"): return
	panel._input(_key(KEY_LEFT))
	if not _check(pick.text == "APERTE UMA TECLA..." and S.key_for("sprint") == KEY_SHIFT, "seta é proibida: continua esperando, nada muda"): return
	panel._input(_key(KEY_ESCAPE))
	if not _check(pick.text == "SHIFT" and S.key_for("sprint") == KEY_SHIFT, "ESC cancela sem mudar"): return
	panel._input(_key(KEY_Q))
	if not _check(pick.text == "SHIFT", "tecla fora da espera não faz nada"): return
	pick.pressed.emit()
	panel._input(_key(KEY_Q))
	if not _check(pick.text == "Q" and S.key_for("sprint") == KEY_Q, "apertou Q: o SPRINT vira Q (%s)" % pick.text): return
	var pick_ability := panel.find_child("Key_ability", true, false).get_node("Pick") as Button
	pick_ability.pressed.emit()
	panel._input(_key(KEY_Q))
	if not _check(pick_ability.text == "Q" and pick.text == "E", "Q já era do SPRINT: trocam entre si e o painel mostra (%s / %s)" % [pick_ability.text, pick.text]): return
	(panel.find_child("ResetControls", true, false) as Button).pressed.emit()
	if not _check(is_equal_approx(slider.value, 0.5) and pick.text == "SHIFT" and pick_ability.text == "E" and is_equal_approx(sample.custom_minimum_size.x, 76.0), "restaurar: tamanho, teclas e amostra voltam"): return
	panel.queue_free()
	await process_frame

	# 4. Na partida
	S.set_value("btn_size", 1.0)   # 140%
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	await _bus.match_started
	await process_frame
	await process_frame
	var hud: Node = _match.get_node("Hud")
	var sprint := hud.find_child("SprintButton", true, false) as Control
	var ability := hud.find_child("AbilityButton", true, false) as Control
	var stock := hud.find_child("Stock", true, false) as Control
	var pause := hud.find_child("PauseButton", true, false) as Control
	var mini: Control = null
	for n in _match.find_children("*", "Control", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("minimap_view.gd"):
			mini = n
	if not _check(sprint != null and ability != null and stock != null and pause != null and mini != null, "HUD tem sprint, habilidade, bônus, pausa e minimapa"): return
	ability.visible = true
	stock.visible = true
	stock.text = "ESPAÇO · VELOCIDADE  [2]"
	var sizes := {}
	for window_size in [Vector2i(960, 540), Vector2i(844, 390), Vector2i(2400, 1080), Vector2i(1024, 768), Vector2i(1280, 800)]:
		root.size = window_size
		await process_frame
		await process_frame
		await process_frame
		var screen := root.get_visible_rect().size
		var rects := {"sprint": sprint.get_global_rect(), "ability": ability.get_global_rect(), "stock": stock.get_global_rect(), "pause": pause.get_global_rect(), "minimap": mini.get_global_rect()}
		for a: String in rects:
			if not _check(Rect2(Vector2.ZERO, screen).encloses(rects[a]), "%s: %s fica dentro da tela %s (%s)" % [window_size, a, screen, rects[a]]): return
			for b: String in rects:
				if a < b and not _check(not rects[a].intersects(rects[b]), "%s: %s e %s não se sobrepõem (%s x %s)" % [window_size, a, b, rects[a], rects[b]]): return
		if not _check(is_equal_approx(sprint.size.x, sprint.size.y) and is_equal_approx(ability.size.x, sprint.size.x), "%s: botões redondos e do mesmo tamanho" % window_size): return
		if not _check(sprint.size.x <= screen.y * L.MAX_HEIGHT_SHARE + 0.01, "%s: botão dentro da fatia da altura (%.1f)" % [window_size, sprint.size.x]): return
		sizes[window_size] = sprint.size.x
	if not _check(is_equal_approx(sizes[Vector2i(960, 540)], 106.4), "140%% em 960x540 = 106,4 (veio %.1f)" % sizes[Vector2i(960, 540)]): return
	root.size = Vector2i(960, 540)
	S.set_value("btn_size", 0.0)   # 60%: a volta da pausa aplica o ajuste novo
	_bus.match_pause_changed.emit(true)
	_bus.match_pause_changed.emit(false)
	await process_frame
	if not _check(is_equal_approx(sprint.size.x, 45.6) and sprint.size.x < sizes[Vector2i(960, 540)], "voltar da pausa aplica o tamanho novo (%.1f)" % sprint.size.x): return

	# 5. Só a tecla escolhida aciona
	S.set_key("sprint", KEY_Q)
	_bus.sprint_used.connect(func(owner_id: int, _cooldown: float): _sprints += 1 if owner_id == 1 else 0)
	_match.get_node("Skills")._unhandled_input(_key(KEY_SHIFT))
	if not _check(_sprints == 0, "a tecla antiga (SHIFT) não aciona mais o sprint"): return
	_match.get_node("Skills")._unhandled_input(_key(KEY_Q))
	if not _check(_sprints == 1, "a tecla nova (Q) aciona o sprint"): return
	S.set_key("bonus", KEY_B)
	_bus.match_pause_changed.emit(true)
	_bus.match_pause_changed.emit(false)
	stock.text = ""
	hud._on_stock(1, ["VELOCIDADE", "GELO"])
	if not _check(stock.text.begins_with("B · VELOCIDADE") and stock.text.contains("[2]"), "o botão do bônus mostra a tecla escolhida (%s)" % stock.text): return
	S.reset_controls()
	print("OK: controles — tamanho 60%–140%, teclas trocáveis sem duplicar, painel com amostra e restaurar, botões sem sobreposição em 5 telas")
	quit(0)
