extends SceneTree
## Teste de fumaça do Passo 158 (DD-197): TUDO POR SETAS + ENTER. Cada tela do menu é aberta e usada só com o teclado, pelo caminho
## inteiro de entrada (foco, ui_*, _input, _unhandled_input): (1) o foco já começa dentro da tela, no primeiro controle habilitado (VOLTAR só
## quando não há outro); (2) todo controle habilitado é alcançável pelas setas; (3) uma seta de verdade leva ao vizinho que o motor aponta;
## (4) ESC fecha; (5) Ajustes: ← → mexem no controle deslizante, ENTER liga/desliga; (6) ONLINE: ↓ passa pelos campos e botões, ENTER no
## campo avança; (7) o menu principal abre e fecha telas e devolve o foco ao atalho; (8) pausa: ↓ e ENTER, ESC volta; (9) sem foco nenhum,
## a primeira seta devolve o foco (nunca fica "perdido").
## Uso: godot_console --headless --path . -s res://tools/smoke_keyboard_nav.gd

const SCREENS := {
	"PERFIL": "profile_screen", "CIVILIZAÇÕES": "civilizations_screen", "LOJA": "shop_screen", "ONLINE": "online_screen",
	"EVENTOS": "events_screen", "MISSÕES": "missions_screen", "PLANETAS": "planet_screen", "PASSE": "pass_screen", "AJUSTES": "settings_panel",
}

var S   # settings.gd (carregado em _run: no modo -s o script compila antes dos autoloads)
var _time := 0.0
var _closed := false


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 120.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _ev(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _tap(code: Key) -> void:   # aperta e solta pelo caminho inteiro da árvore (o botão só dispara ao soltar)
	root.push_input(_ev(code, true))
	root.push_input(_ev(code, false))


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _frames(count := 2) -> void:
	for i in count:
		await process_frame


## Controles que o teclado deve alcançar: botões, controles deslizantes e campos de texto, visíveis e habilitados.
func _focusables(node: Node) -> Array:
	var out := []
	for found in node.find_children("*", "Control", true, false):
		var c := found as Control
		if c.focus_mode == Control.FOCUS_NONE or not c.is_visible_in_tree():
			continue
		if c is BaseButton and (c as BaseButton).disabled:
			continue
		if c is BaseButton or c is Slider or c is LineEdit:
			out.append(c)
	return out


## Tudo o que as setas alcançam a partir de `start` (a mesma busca que o motor faz a cada seta).
func _reachable(start: Control) -> Array:
	var seen := [start]
	var queue := [start]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var n := c.find_valid_focus_neighbor(side)
			if n != null and not seen.has(n):
				seen.append(n)
				queue.append(n)
	return seen


func _names(list: Array) -> String:
	var out := PackedStringArray()
	for c: Control in list:
		out.append(String(c.name))
	return ", ".join(out)


func _run() -> void:
	Input.use_accumulated_input = false
	Profile.path = "user://profile_smoke_keyboard_nav.json"
	Profile.data = Profile.defaults()
	Profile.data["matches"] = 20   # fora do treino: o menu todo habilitado
	Profile.save()
	S = load("res://scripts/core/settings.gd")

	# 1 a 4. Cada tela do menu, só com o teclado
	for title: String in SCREENS:
		var screen: Control = load("res://scripts/ui/%s.gd" % SCREENS[title]).new()
		_closed = false
		screen.closed.connect(func(): _closed = true)
		root.add_child(screen)
		await _frames()
		var first := _focus()
		if not _check(first != null and screen.is_ancestor_of(first), "%s: o foco já começa dentro da tela" % title): return
		var all := _focusables(screen)
		var others := all.filter(func(c: Control) -> bool: return c.name != "Back")
		if not _check(not others.is_empty() or first.name == "Back", "%s: sem nada para usar, só o VOLTAR" % title): return
		if not _check(others.is_empty() or first.name != "Back", "%s: o foco deve começar no primeiro controle, não no VOLTAR" % title): return
		var reach := _reachable(first)
		var lost := all.filter(func(c: Control) -> bool: return not reach.has(c))
		if not _check(lost.is_empty(), "%s: as setas não chegam em: %s" % [title, _names(lost)]): return
		var below := first.find_valid_focus_neighbor(SIDE_BOTTOM)
		if below != null:
			_tap(KEY_DOWN)
			if not _check(_focus() == below, "%s: a seta ↓ leva ao vizinho de baixo (%s, foi para %s)" % [title, below.name, _focus().name if _focus() != null else "nada"]): return
			_tap(KEY_UP)
			# o motor escolhe o vizinho de cima pela geometria (numa fila de abas pode ser a aba vizinha, não a mesma): basta não travar
			if not _check(_focus() != null and _focus() != below and screen.is_ancestor_of(_focus()), "%s: a seta ↑ sai do vizinho de baixo sem perder o foco" % title): return
		_tap(KEY_ESCAPE)
		await _frames()
		if not _check(_closed, "%s: ESC fecha a tela" % title): return
		screen.queue_free()
		await _frames()

	# 5. Ajustes: ← → no controle deslizante, ENTER no liga/desliga
	var panel: Control = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await _frames()
	var sfx := panel.find_child("Sfx", true, false) as HSlider
	var music := panel.find_child("Music", true, false) as HSlider
	if not _check(_focus() == sfx, "ajustes: o foco começa em EFEITOS"): return
	sfx.value = 0.5
	_tap(KEY_RIGHT)
	if not _check(is_equal_approx(sfx.value, 0.55), "ajustes: → sobe um passo no controle deslizante (%s)" % sfx.value): return
	if not _check(is_equal_approx(float(S.get_value("sfx")), 0.55), "ajustes: o valor vale na hora"): return
	_tap(KEY_LEFT)
	_tap(KEY_LEFT)
	if not _check(is_equal_approx(sfx.value, 0.45), "ajustes: ← desce (%s)" % sfx.value): return
	_tap(KEY_DOWN)
	if not _check(_focus() == music, "ajustes: ↓ passa de EFEITOS para MÚSICA"): return
	var haptics := panel.find_child("Haptics", true, false) as CheckButton
	haptics.grab_focus()
	var before: bool = haptics.button_pressed
	_tap(KEY_ENTER)
	if not _check(haptics.button_pressed != before and S.haptics_on() != before, "ajustes: ENTER liga/desliga a vibração"): return
	_tap(KEY_ENTER)
	var q2 := panel.find_child("Q2", true, false) as Button
	q2.grab_focus()
	_tap(KEY_ENTER)
	if not _check(int(S.get_value("quality")) == 2, "ajustes: ENTER escolhe a qualidade"): return
	var arrows := panel.find_child("Arrows", true, false) as Button
	arrows.grab_focus()
	_tap(KEY_ENTER)
	if not _check(S.key_for("left") == KEY_LEFT, "ajustes: ENTER troca o esquema de teclas"): return
	var pick := panel.find_child("Key_sprint", true, false).get_node("Pick") as Button
	pick.grab_focus()
	_tap(KEY_ENTER)
	if not _check(pick.text.begins_with("APERTE"), "ajustes: ENTER no botão da tecla espera a nova tecla"): return
	_tap(KEY_F)
	if not _check(S.key_for("sprint") == KEY_F and _focus() == pick, "ajustes: a tecla nova vale e o foco fica no botão"): return
	S.reset_controls()
	panel.free()
	await _frames()

	# 6. ONLINE: ↓ passa pelos campos e botões; ENTER no campo avança
	var online: Control = load("res://scripts/ui/online_screen.gd").new()
	root.add_child(online)
	await _frames()
	var address := online.find_child("Address", true, false) as LineEdit
	var port := online.find_child("Port", true, false) as LineEdit
	var join := online.find_child("Join", true, false) as Button
	var host := online.find_child("Host", true, false) as Button
	var back := online.find_child("Back", true, false) as Button
	if not _check(_focus() == address, "online: o foco começa no endereço"): return
	for target: Control in [port, join, host, back]:
		_tap(KEY_DOWN)
		if not _check(_focus() == target, "online: ↓ chega em %s (foi para %s)" % [target.name, _focus().name if _focus() != null else "nada"]): return
	for target: Control in [host, join, port, address]:
		_tap(KEY_UP)
		if not _check(_focus() == target, "online: ↑ volta para %s" % target.name): return
	_tap(KEY_ENTER)
	if not _check(_focus() == port, "online: ENTER no endereço passa para a porta"): return
	_tap(KEY_ENTER)
	if not _check(_focus() == join, "online: ENTER na porta passa para ENTRAR"): return
	online.free()
	await _frames()

	# 7. Menu principal: abrir e fechar telas só com o teclado
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(3)
	var play := menu.get_node("Box/Play") as Button
	if not _check(_focus() == play, "menu: o foco começa em JOGAR"): return
	var menu_all := _focusables(menu.get_node("Box"))
	var menu_lost := menu_all.filter(func(c: Control) -> bool: return not _reachable(play).has(c))
	if not _check(menu_lost.is_empty(), "menu: as setas não chegam em: %s" % _names(menu_lost)): return
	for entry: Array in [["Box/Dock/Shop", "LOJA"], ["Box/Dock/Missions", "MISSÕES"], ["Box/Pass", "PASSE"], ["Box/Footer/Settings", "AJUSTES"]]:
		var button := menu.get_node(entry[0]) as Button
		button.grab_focus()
		_tap(KEY_ENTER)
		await _frames()
		var opened := menu.get_node_or_null("Screen")
		if opened == null:
			opened = menu.get_node_or_null("SettingsPanel")
		if not _check(opened != null, "menu: ENTER abre %s" % entry[1]): return
		if not _check(_focus() != null and opened.is_ancestor_of(_focus()), "menu: o foco vai para dentro de %s" % entry[1]): return
		_tap(KEY_ESCAPE)
		await _frames(2)
		if not _check(menu.get_node_or_null("Screen") == null and menu.get_node_or_null("SettingsPanel") == null, "menu: ESC fecha %s" % entry[1]): return
		if not _check(_focus() == button, "menu: o foco volta para %s" % button.name): return

	# 9. Sem foco nenhum, a primeira seta devolve o foco
	var shop: Control = load("res://scripts/ui/shop_screen.gd").new()
	root.add_child(shop)
	await _frames()
	root.gui_release_focus()
	if not _check(_focus() == null, "foco solto"): return
	_tap(KEY_DOWN)
	if not _check(_focus() != null and shop.is_ancestor_of(_focus()), "sem foco: ↓ devolve o foco à tela"): return
	shop.free()
	menu.free()
	await _frames()

	# 8. Pausa: ↓ e ENTER, ESC volta
	var pause: Node = load("res://scripts/ui/pause_panel.gd").new()
	root.add_child(pause)
	await _frames()
	pause.open()
	await _frames()
	var resume := pause.find_child("Resume", true, false) as Button
	var settings_button := pause.find_child("Settings", true, false) as Button
	var quit_button := pause.find_child("Quit", true, false) as Button
	if not _check(_focus() == resume, "pausa: o foco começa em CONTINUAR"): return
	_tap(KEY_DOWN)
	if not _check(_focus() == settings_button, "pausa: ↓ vai para CONFIGURAÇÕES"): return
	_tap(KEY_DOWN)
	if not _check(_focus() == quit_button, "pausa: ↓ vai para SAIR DA PARTIDA"): return
	_tap(KEY_ENTER)
	await _frames()   # a caixa da confirmação acabou de aparecer: o motor só posiciona os botões no quadro seguinte
	var confirm_back := pause.find_child("Back", true, false) as Button
	if not _check(_focus() == confirm_back, "pausa: ENTER em SAIR pede confirmação, com o foco no seguro (VOLTAR)"): return
	_tap(KEY_DOWN)
	if not _check(_focus() != null and _focus().name == "Leave", "pausa: ↓ chega em SAIR E PERDER A PARTIDA (foi para %s)" % [_focus().name if _focus() != null else "nada"]): return
	_tap(KEY_ESCAPE)
	if not _check(_focus() == resume, "pausa: ESC na confirmação volta ao menu da pausa"): return
	_tap(KEY_ESCAPE)
	if not _check(not pause.is_open and not paused, "pausa: ESC fecha e a partida volta"): return
	pause.free()

	Input.use_accumulated_input = true
	print("OK")
	quit(0)
