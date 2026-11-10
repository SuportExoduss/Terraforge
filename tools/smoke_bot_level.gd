extends SceneTree
## Teste de fumaça do Passo 54 (bots no nível do jogador, DD-066): a ambição sorteada dos bots acompanha o rating —
## rating 1000 mantém o sorteio 0,6…1,6; rating alto empurra para cima (até +0,2), baixo para baixo (até -0,2, piso 0,5);
## e a partida usa isso ao criar os bots.
## Uso: godot_console --headless --path . -s res://tools/smoke_bot_level.gd

const TEST_PROFILE := "user://profile_smoke_botlevel.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


## Menor e maior ambição em 400 sorteios para esse rating.
func _range(rating: int) -> Vector2:
	var bot = load("res://scripts/ai/bot_steering.gd")
	var low := 99.0
	var high := -99.0
	for i in 400:
		var value: float = bot.ambition_for(rating)
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# Faixas por rating: o meio (1000) é o sorteio original; ±200 ou mais desloca 0,2; o piso é 0,5
	var mid := _range(1000)
	if not _check(mid.x >= 0.6 and mid.y <= 1.6 and mid.x < 0.7 and mid.y > 1.5, "rating 1000: 0,6…1,6 (%s)" % mid): return
	var strong := _range(1200)
	if not _check(strong.x >= 0.8 and strong.y <= 1.8 and strong.x < 0.9 and strong.y > 1.7, "rating 1200: 0,8…1,8 (%s)" % strong): return
	var beyond := _range(9000)
	if not _check(beyond.x >= 0.8 and beyond.y <= 1.8, "rating altíssimo não passa de +0,2 (%s)" % beyond): return
	var weak := _range(800)
	if not _check(weak.x >= 0.5 and weak.x < 0.6 and weak.y <= 1.4 and weak.y > 1.3, "rating 800: 0,5 (piso)…1,4 (%s)" % weak): return
	var zero := _range(0)
	if not _check(zero.x >= 0.5 and zero.y <= 1.4, "rating 0 não passa de -0,2 (%s)" % zero): return

	# A partida usa o rating do perfil: com 1200, nenhum bot nasce abaixo de 0,8
	profile.data["rating"] = 1200
	var match_node: Node = load("res://scenes/match.tscn").instantiate()
	match_node.get_node("MatchSetup").skip_ceremony = true
	match_node.get_node("MatchSetup").bot_count = 5
	root.add_child(match_node)
	await process_frame
	var brains := match_node.find_children("Steering", "BotSteering", true, false)
	if not _check(brains.size() == 5, "5 bots na partida (%d)" % brains.size()): return
	for brain in brains:
		if not _check(brain.ambition >= 0.8 and brain.ambition <= 1.8, "bot com ambição %.2f fora de 0,8…1,8" % brain.ambition): return

	match_node.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_bot_level")
	quit(0)
