extends SceneTree
## Teste de fumaça do Passo 106 (DD-146, tutorial como primeira partida): (1) quem nunca jogou (matches = 0) vê o menu com
## "PRIMEIRA PARTIDA" (botão travado) e o JOGAR abre o TREINO: planeta pequeno, 1 bot manso, 180 s, HUD com o TutorialCoach;
## (2) as dicas saem uma vez, nas horas certas (largada, circuito fechado, dano, evento, bônus, tempo sem circuito);
## (3) depois de jogar (matches = 1) o menu volta ao planeta escolhido e o JOGAR DE NOVO do treino vai para o planeta de verdade.
## Uso: godot_console --headless --path . -s res://tools/smoke_tutorial.gd

const PROFILE_FILE := "user://profile_smoke_tutorial.json"

var _time := 0.0


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DirAccess.remove_absolute(PROFILE_FILE)
	quit(1)


func _initialize() -> void:
	Profile.path = PROFILE_FILE   # perfil só deste teste: o do jogo (e o dos outros testes) não muda
	DirAccess.remove_absolute(PROFILE_FILE)
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 90.0:
		_fail("tempo esgotado")
	return false


func _settle() -> void:
	for i in 5:
		await process_frame
	await create_timer(0.3).timeout


func _run() -> void:
	await process_frame
	var services: Node = root.get_node("Services")
	var bus: Node = root.get_node("EventBus")
	var menu := current_scene

	# 1. Perfil novo: o menu oferece o treino, sem escolha de planeta
	var planet_button: Button = menu.get_node("Box/Planet")
	if not (planet_button.disabled and planet_button.text.begins_with("PRIMEIRA PARTIDA") and services.match_def.tutorial):
		return _fail("o menu de quem nunca jogou deveria mostrar a PRIMEIRA PARTIDA travada (texto '%s')" % planet_button.text)
	var def: Resource = services.match_def
	if def.radius >= 100.0 or def.bots != 1 or def.duration_seconds > 240.0 or not def.calm:
		return _fail("o treino deveria ser pequeno, curto e com 1 bot manso")

	# 2. JOGAR abre a partida do treino
	menu.approach_seconds = 0.0
	menu.get_node("Box/Play").pressed.emit()
	await _settle()
	var match_scene := current_scene
	if match_scene.name != "Match":
		return _fail("JOGAR deveria abrir a partida")
	if not is_equal_approx(services.planet.radius, def.radius):
		return _fail("o treino deveria rodar no planeta pequeno (raio %f)" % services.planet.radius)
	if match_scene.get_node_or_null("Main/Runner2") == null or match_scene.get_node_or_null("Main/Runner3") != null:
		return _fail("o treino deveria ter exatamente 1 bot")
	var brain: Node = match_scene.get_node("Main/Runner2/Steering")
	if brain.ambition > 0.51 or brain.calm_seconds < 1000.0:
		return _fail("o bot do treino deveria ser manso (ambição %.2f, calma %.0f s)" % [brain.ambition, brain.calm_seconds])
	var coach: Node = match_scene.get_node_or_null("Hud/Root/Coach")
	if coach == null:
		return _fail("a HUD do treino deveria ter o TutorialCoach")

	# 3. As dicas: cada uma na sua hora, cada uma uma vez só
	bus.match_started.emit()
	if not (Array(coach.shown) == ["steer"] and coach.current_text().contains("Arraste")):
		return _fail("na largada deveria sair a dica de virar (saiu %s)" % [coach.shown])
	bus.territory_loop_claimed.emit(2, 50)   # circuito do BOT: não é com o jogador
	bus.damage_taken.emit(2, 2, "RASTRO")
	if Array(coach.shown) != ["steer"]:
		return _fail("o que acontece com os outros não deveria gerar dica (saiu %s)" % [coach.shown])
	bus.territory_loop_claimed.emit(1, 0)   # circuito vazio: ainda não conquistou nada
	if coach.shown.has("claimed"):
		return _fail("circuito vazio não deveria dar os parabéns")
	bus.territory_loop_claimed.emit(1, 120)
	bus.damage_taken.emit(1, 2, "RASTRO CORTADO")
	bus.global_event_warning.emit("CHUVA DE METEOROS", 5)
	bus.global_event_warning.emit("CHUVA DE METEOROS", 0)   # o IMPACTO não é aviso
	bus.bonus_stock_changed.emit(1, ["ESCUDO TEMPORAL"])
	if Array(coach.shown) != ["steer", "claimed", "hurt", "event", "bonus"]:
		return _fail("ordem das dicas inesperada: %s" % [coach.shown])
	bus.territory_loop_claimed.emit(1, 80)
	bus.damage_taken.emit(1, 2, "RASTRO CORTADO")
	if coach.shown.size() != 5:
		return _fail("cada dica deveria sair uma única vez (saíram %d)" % coach.shown.size())
	if coach.get("_closed_loop") != true:
		return _fail("com o circuito fechado a dica de lembrete não deve mais sair")

	var tips := str(coach.shown)
	# 4. A dica de lembrete: sem fechar circuito por NUDGE_SECONDS, ela aparece
	var late: Node = load("res://scripts/ui/tutorial_coach.gd").new()
	match_scene.get_node("Hud/Root").add_child(late)
	late.set("_started", true)
	late._process(late.NUDGE_SECONDS + 1.0)
	if not late.shown.has("loop"):
		return _fail("sem circuito depois de %d s deveria sair a dica de como fechar um" % late.NUDGE_SECONDS)

	# 5. Fim da partida: JOGAR DE NOVO do treino vai para o planeta de verdade (o perfil já contou a partida)
	services.flow.pace = 0.0
	bus.match_ended.emit()
	await process_frame
	Profile.data["matches"] = 1   # (o fim de partida do jogo já contou; aqui fixamos o estado do perfil deste teste)
	Profile.data["planet"] = "pequeno"
	var again: Button = match_scene.get_node("Results/Panel/Box/Buttons/PlayAgain")
	again.pressed.emit()
	await _settle()
	if services.match_def.tutorial or services.match_def.id != "pequeno":
		return _fail("depois do treino o JOGAR DE NOVO deveria usar o planeta do perfil (veio '%s')" % services.match_def.id)

	# 6. Com 1 partida no perfil o menu volta ao normal: planeta escolhido, botão livre
	Profile.save()
	var menu_scene: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu_scene)
	current_scene = menu_scene
	await process_frame
	var normal_button: Button = menu_scene.get_node("Box/Planet")
	if normal_button.disabled or not normal_button.text.begins_with("PLANETA: Pequeno") or services.match_def.tutorial:
		return _fail("depois da primeira partida o menu deveria voltar ao planeta escolhido (texto '%s')" % normal_button.text)
	print("tutorial: menu trava a 1ª partida no treino (%s), 1 bot manso, dicas %s, depois volta ao normal" % [def.summary(), tips])
	DirAccess.remove_absolute(PROFILE_FILE)
	services.match_def = null
	print("OK")
	quit(0)
