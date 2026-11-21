extends SceneTree
## Teste de fumaça do Passo 157 (DD-196): CONTROLES DE PC. (1) a pergunta da primeira vez (A/D ou setas): as setas e ENTER escolhem, o outro par
## fica para o mapa, ESC fecha sem escolher; (2) girar o personagem pela tecla escolhida (e a seta que é do mapa NÃO gira); (3) no mapa aberto
## o OUTRO par move a vista e +/- dão zoom, M abre/fecha em paralelo e ESC fecha o mapa antes de pausar; (4) a HUD no PC só mostra (timers
## empilhados à direita, com a tecla ao lado, sem clique); (5) o painel de Ajustes troca o esquema e mostra o que o mapa usa.
## Uso: godot_console --headless --path . -s res://tools/smoke_pc_controls.gd

var S   # settings.gd (carregado em _run: no modo -s o script compila antes dos autoloads)
var _bus: Node
var _match: Node
var _time := 0.0
var _pauses := 0
var _drag := Vector2.ZERO
var _zoom := 1.0


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


func _ev(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _tap(code: Key) -> void:   # aperta e solta pelo caminho inteiro da árvore (foco, ui_*, _input, _unhandled_input)
	root.push_input(_ev(code, true))
	root.push_input(_ev(code, false))


func _hold(code: Key, down: bool) -> void:   # tecla segurada que o Input enxerga (is_key_pressed)
	Input.parse_input_event(_ev(code, down))


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _run() -> void:
	Input.use_accumulated_input = false
	Profile.path = "user://profile_smoke_pc_controls.json"
	Profile.data = Profile.defaults()
	Profile.save()
	S = load("res://scripts/core/settings.gd")

	# 1. A pergunta da primeira vez
	if not _check(S.is_pc() and not S.scheme_asked(), "no PC, perfil novo: ainda não perguntou"): return
	var prompt: Control = load("res://scripts/ui/scheme_prompt.gd").new()
	root.add_child(prompt)
	await process_frame
	await process_frame
	var wasd := prompt.find_child("Wasd", true, false) as Button
	var arrows := prompt.find_child("Arrows", true, false) as Button
	if not _check(wasd != null and arrows != null and _focus() == wasd, "pergunta: A/D e setas, com o foco em A/D"): return
	_tap(KEY_RIGHT)
	if not _check(_focus() == arrows, "→ passa o foco para as setas"): return
	_tap(KEY_LEFT)
	if not _check(_focus() == wasd, "← volta o foco para A/D"): return
	_tap(KEY_ESCAPE)
	await process_frame
	if not _check(not is_instance_valid(prompt) or prompt.is_queued_for_deletion(), "ESC fecha a pergunta"): return
	if not _check(not S.scheme_asked(), "ESC não escolhe: pergunta de novo da próxima vez"): return
	for case in [[KEY_RIGHT, 2, KEY_LEFT, KEY_RIGHT], [KEY_NONE, 1, KEY_A, KEY_D]]:
		prompt = load("res://scripts/ui/scheme_prompt.gd").new()
		root.add_child(prompt)
		await process_frame
		await process_frame
		if case[0] != KEY_NONE:
			_tap(case[0])
		_tap(KEY_ENTER)
		await process_frame
		if not _check(S.scheme_asked() and int(S.get_value("scheme")) == case[1], "ENTER escolhe o esquema %d" % case[1]): return
		if not _check(S.key_for("left") == case[2] and S.key_for("right") == case[3], "esquema %d: girar com %s / %s" % [case[1], S.key_label("left"), S.key_label("right")]): return
		if not _check(not is_instance_valid(prompt) or prompt.is_queued_for_deletion(), "a pergunta some depois de escolher"): return

	# 2. O mapa usa o OUTRO par; girar usa só o par escolhido
	S.set_scheme(1)   # A / D
	if not _check(S.map_pan_keys() == [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and S.map_pan_text() == "← ↑ ↓ →", "gira com A/D: o mapa usa as setas"): return
	_hold(KEY_A, true)
	if not _check(S.steer_axis() == -1.0, "A gira à esquerda"): return
	_hold(KEY_A, false)
	_hold(KEY_D, true)
	if not _check(S.steer_axis() == 1.0, "D gira à direita"): return
	_hold(KEY_D, false)
	_hold(KEY_LEFT, true)
	if not _check(S.steer_axis() == 0.0, "gira com A/D: a seta é do mapa e NÃO gira"): return
	_hold(KEY_LEFT, false)
	S.set_scheme(2)   # setas
	if not _check(S.map_pan_keys() == [KEY_A, KEY_D, KEY_W, KEY_S] and S.map_pan_text() == "W A S D", "gira com as setas: o mapa usa W A S D"): return
	_hold(KEY_LEFT, true)
	if not _check(S.steer_axis() == -1.0, "← gira à esquerda"): return
	_hold(KEY_LEFT, false)
	_hold(KEY_A, true)
	if not _check(S.steer_axis() == 0.0, "gira com as setas: o A é do mapa e NÃO gira"): return
	_hold(KEY_A, false)

	# 3. Na partida: mapa com M em paralelo, ESC fecha o mapa antes de pausar
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
	_bus.match_pause_changed.connect(func(on: bool): _pauses += 1 if on else 0)
	_bus.minimap_dragged.connect(func(d: Vector2): _drag += d)
	_bus.minimap_zoomed.connect(func(f: float): _zoom *= f)
	var mini: Control = null
	for n in _match.find_children("*", "Control", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("minimap_view.gd"):
			mini = n
	if not _check(mini != null and not mini._expanded, "minimapa começa pequeno"): return
	var hint := mini.get_node_or_null("KeyHint") as Label
	if not _check(hint != null and hint.text == "M  MAPA", "o minimapa mostra a tecla (%s)" % (hint.text if hint else "sem dica")): return
	_tap(KEY_M)
	if not _check(mini._expanded and hint.text.contains("W A S D"), "M abre o mapa e a dica mostra o par do mapa (%s)" % hint.text): return
	_hold(KEY_D, true)   # esquema 2 (setas): W A S D movem o mapa
	await create_timer(0.3).timeout
	_hold(KEY_D, false)
	if not _check(_drag.x < -1.0 and absf(_drag.y) < 0.001, "D com o mapa aberto move a vista (%s)" % _drag): return
	_drag = Vector2.ZERO
	_hold(KEY_LEFT, true)   # seta não mexe no mapa (é a do personagem)
	await create_timer(0.2).timeout
	_hold(KEY_LEFT, false)
	if not _check(_drag == Vector2.ZERO, "← com o mapa aberto gira o personagem, não o mapa"): return
	_hold(KEY_EQUAL, true)
	await create_timer(0.3).timeout
	_hold(KEY_EQUAL, false)
	if not _check(_zoom > 1.1, "+ aproxima o mapa (%.2f)" % _zoom): return
	_hold(KEY_MINUS, true)
	await create_timer(0.5).timeout
	_hold(KEY_MINUS, false)
	if not _check(_zoom < 1.1, "− afasta o mapa (%.2f)" % _zoom): return
	var pauses_before := _pauses
	_tap(KEY_ESCAPE)
	await process_frame
	if not _check(not mini._expanded and _pauses == pauses_before, "ESC com o mapa aberto só fecha o mapa (sem pausar)"): return
	_tap(KEY_ESCAPE)
	await process_frame
	if not _check(_pauses == pauses_before + 1, "o segundo ESC pausa"): return
	_tap(KEY_ESCAPE)   # fecha a pausa
	await process_frame
	_tap(KEY_M)
	if not _check(mini._expanded, "M abre de novo"): return
	_tap(KEY_M)
	if not _check(not mini._expanded, "M fecha o mapa"): return
	if not _check(S.set_key("map", KEY_N), "troca a tecla do mapa para N"): return
	_tap(KEY_M)
	if not _check(not mini._expanded, "a tecla antiga (M) não abre mais"): return
	_tap(KEY_N)
	if not _check(mini._expanded, "a nova (N) abre"): return
	_tap(KEY_N)
	S.set_key("map", KEY_M)

	# 4. HUD só mostra
	var hud: Node = _match.get_node("Hud")
	var sprint := hud.find_child("SprintButton", true, false) as Control
	var ability := hud.find_child("AbilityButton", true, false) as Control
	var stock := hud.find_child("Stock", true, false) as Control
	if not _check(sprint.mouse_filter == Control.MOUSE_FILTER_IGNORE and ability.mouse_filter == Control.MOUSE_FILTER_IGNORE and stock.mouse_filter == Control.MOUSE_FILTER_IGNORE, "no PC os indicadores da HUD não recebem clique (só mostram)"): return
	var sprint_hint := sprint.get_node_or_null("KeyHint") as Label
	var ability_hint := ability.get_node_or_null("KeyHint") as Label
	if not _check(sprint_hint != null and sprint_hint.visible and sprint_hint.text == "ALT" and ability_hint != null and ability_hint.text == "SHIFT", "a HUD mostra ALT (sprint) e SHIFT (habilidade) ao lado dos timers"): return
	if not _check(is_equal_approx(sprint.get_global_rect().end.x, ability.get_global_rect().end.x) and ability.get_global_rect().end.y <= sprint.get_global_rect().position.y, "timers enfileirados na direita: habilidade em cima, sprint embaixo"): return
	S.set_key("sprint", KEY_Q)
	_bus.match_pause_changed.emit(true)
	_bus.match_pause_changed.emit(false)
	await process_frame
	if not _check(sprint_hint.text == "Q", "trocar a tecla nas Ajustes muda a dica na HUD (%s)" % sprint_hint.text): return
	S.reset_controls()
	_match.queue_free()
	await process_frame

	# 5. Painel de Ajustes
	S.set_scheme(1)
	var panel = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await process_frame
	await process_frame
	var wasd_btn := panel.find_child("Wasd", true, false) as Button
	var arrows_btn := panel.find_child("Arrows", true, false) as Button
	var map_hint := panel.find_child("MapHint", true, false) as Label
	if not _check(wasd_btn != null and arrows_btn != null and map_hint != null, "painel: esquema de giro e dica do mapa"): return
	if not _check(wasd_btn.button_pressed and not arrows_btn.button_pressed and map_hint.text.contains("← ↑ ↓ →"), "A/D marcado: o mapa usa as setas (%s)" % map_hint.text): return
	var left_pick := panel.find_child("Key_left", true, false).get_node("Pick") as Button
	var right_pick := panel.find_child("Key_right", true, false).get_node("Pick") as Button
	var map_pick := panel.find_child("Key_map", true, false).get_node("Pick") as Button
	if not _check(left_pick.text == "A" and right_pick.text == "D" and map_pick.text == "M", "teclas: A / D / M (%s %s %s)" % [left_pick.text, right_pick.text, map_pick.text]): return
	arrows_btn.pressed.emit()
	if not _check(S.key_for("left") == KEY_LEFT and S.key_for("right") == KEY_RIGHT and arrows_btn.button_pressed and not wasd_btn.button_pressed, "escolher as setas no painel troca as teclas de girar"): return
	if not _check(left_pick.text == "←" and right_pick.text == "→" and map_hint.text.contains("W A S D"), "o painel mostra ← / → e o mapa em W A S D (%s)" % map_hint.text): return
	map_pick.pressed.emit()
	panel._input(_ev(KEY_UP, true))
	if not _check(map_pick.text == "APERTE UMA TECLA...", "seta para cima não vale como tecla do mapa"): return
	panel._input(_ev(KEY_N, true))
	if not _check(map_pick.text == "N" and S.key_for("map") == KEY_N and map_hint.text.contains("(N)"), "N vira a tecla do mapa e a dica acompanha (%s)" % map_hint.text): return
	(panel.find_child("ResetControls", true, false) as Button).pressed.emit()
	if not _check(map_pick.text == "M" and left_pick.text == "←" and not wasd_btn.button_pressed, "restaurar volta a M e às setas (sem esquema escolhido)"): return
	panel.queue_free()
	await process_frame
	Input.use_accumulated_input = true
	print("OK: controles de PC — pergunta A/D ou setas (setas+ENTER), mapa com M no outro par com zoom, ESC fecha o mapa antes de pausar, HUD só mostra, painel troca o esquema")
	quit(0)
