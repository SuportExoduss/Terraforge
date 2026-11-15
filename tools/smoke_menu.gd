extends SceneTree
## Teste de fumaça do Passo 18 (menu e "jogar de novo"): (1) o menu mostra JOGAR e SAIR; JOGAR leva à partida;
## (2) os botões dos resultados só aparecem no fim; (3) JOGAR DE NOVO recarrega uma partida nova e inteira;
## (4) MENU volta ao menu. Uso: godot_console --headless --path . -s res://tools/smoke_menu.gd

var _time := 0.0


func _initialize() -> void:
	Profile.path = "user://profile_smoke_menu.json"   # perfil próprio, de quem já jogou (a 1ª partida é o treino, Passo 106: smoke_tutorial)
	Profile.data = Profile.defaults()
	Profile.data["matches"] = 1
	Profile.save()
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _settle() -> void:
	for i in 5:
		await process_frame
	await create_timer(0.3).timeout


func _run() -> void:
	await process_frame
	var menu := current_scene
	if not _check(menu.name == "Menu" and menu.get_node("Box/Play").text == "JOGAR" and menu.get_node("Box/Quit").text == "SAIR", "menu com JOGAR e SAIR"): return
	if not _check(menu.get_node("Box/Title").text == "TERRAFORGE", "título"): return
	if not _check(menu.get_node("Box/Profile").text.begins_with("Nível ") and menu.get_node("Box/Profile").text.contains("conquistas "), "linha de perfil (nível/XP/moedas/conquistas)"): return
	# Planeta (DD-143): o botão mostra o Médio, um toque vai ao Pequeno (e lembra no perfil), outro volta ao Médio
	var planet_button: Button = menu.get_node("Box/Planet")
	var services: Node = root.get_node("Services")
	if not _check(planet_button.text.begins_with("PLANETA: Médio") and services.match_def.id == "medio", "botão de planeta começa no Médio"): return
	planet_button.pressed.emit()
	if not _check(planet_button.text.begins_with("PLANETA: Pequeno") and services.match_def.id == "pequeno" and services.match_def.radius < 100.0, "toque troca para o Pequeno"): return
	planet_button.pressed.emit()
	if not _check(planet_button.text.begins_with("PLANETA: Médio") and services.match_def.id == "medio", "outro toque volta ao Médio"): return
	# Geometria (bug: com set_anchors_preset o menu ficava no canto da tela, sem fundo): fundo cobre a tela e a caixa fica no centro
	await process_frame
	var screen: Vector2 = menu.get_viewport_rect().size
	var box_rect: Rect2 = menu.get_node("Box").get_global_rect()
	# Passo 109: a coluna de botões fica à esquerda (o planeta grande ocupa a direita), centrada na vertical e inteira na tela
	if not _check(menu.get_child(0).size == screen and absf(box_rect.get_center().y - screen.y * 0.5) < 2.0 and box_rect.position.x >= 24.0 and box_rect.end.x <= screen.x * 0.55 and box_rect.position.y >= 0.0 and box_rect.end.y <= screen.y, "menu deve cobrir a tela e a coluna ficar à esquerda, centrada na vertical e inteira na tela (fundo %s, coluna %s, tela %s)" % [menu.get_child(0).size, box_rect, screen]): return

	# 1. JOGAR leva à partida; os botões dos resultados ainda não aparecem
	menu.approach_seconds = 0.0   # sem o mergulho (ele tem o smoke_approach)
	menu.get_node("Box/Play").pressed.emit()
	await _settle()
	var first := current_scene
	if not _check(first.name == "Match" and is_instance_valid(first) and not is_instance_valid(menu), "JOGAR abre a partida"): return
	var panel: Control = first.get_node("Results/Panel")
	var again: Button = first.get_node("Results/Panel/Box/Buttons/PlayAgain")
	if not _check(not panel.visible and not again.is_visible_in_tree(), "botões escondidos durante a partida"): return

	# 2. No fim da partida os botões aparecem
	root.get_node("Services").flow.pace = 0.0   # pós-jogo instantâneo
	root.get_node("EventBus").match_ended.emit()
	await process_frame
	if not _check(again.is_visible_in_tree() and again.text == "JOGAR DE NOVO" and first.get_node("Results/Panel/Box/Buttons/Menu").is_visible_in_tree(), "botões no fim da partida"): return

	# 3. JOGAR DE NOVO: partida nova, com o planeta e os serviços de pé
	again.pressed.emit()
	await _settle()
	var second := current_scene
	if not _check(second != first and second.name == "Match" and not is_instance_valid(first), "JOGAR DE NOVO troca por uma partida nova"): return
	if not _check(not second.get_node("Results/Panel").visible, "a partida nova começa sem painel"): return
	if not _check(root.get_node("Services").planet != null and second.get_node_or_null("Main/HomeBase4") != null and second.get_node_or_null("Main/Runner4") != null, "planeta, bases e corredores na partida nova"): return

	# 4. MENU volta ao início
	root.get_node("Services").flow.pace = 0.0   # pós-jogo instantâneo
	root.get_node("EventBus").match_ended.emit()
	await process_frame
	second.get_node("Results/Panel/Box/Buttons/Menu").pressed.emit()
	await _settle()
	if not _check(current_scene.name == "Menu" and not is_instance_valid(second), "MENU volta ao menu"): return
	print("OK")
	quit(0)
