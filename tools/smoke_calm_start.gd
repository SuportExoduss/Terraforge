extends SceneTree
## Teste de fumaça do Passo 45 (DD-012, começo calmo): nos primeiros segundos o bot não caça rastro inimigo (poucos
## confrontos no 1º minuto); a caça volta a crescer até o alcance pleno em ~45 s.
## Uso: godot_console --headless --path . -s res://tools/smoke_calm_start.gd


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	var brain = load("res://scripts/ai/bot_steering.gd").new()
	# curva: 0 até calm_seconds, sobe linear, 1 aos calm+ramp (45 s)
	brain.age = 0.0
	if not _check(brain.hunt_scale() == 0.0, "no início não caça (%f)" % brain.hunt_scale()): return
	brain.age = brain.calm_seconds
	if not _check(brain.hunt_scale() == 0.0, "no fim da calma ainda zero"): return
	brain.age = brain.calm_seconds + brain.ramp_seconds * 0.5
	if not _check(absf(brain.hunt_scale() - 0.5) < 0.001, "no meio da subida = 0,5"): return
	brain.age = brain.calm_seconds + brain.ramp_seconds
	if not _check(brain.hunt_scale() == 1.0, "alcance pleno ao fim da subida"): return
	if not _check(is_equal_approx(brain.calm_seconds + brain.ramp_seconds, 45.0), "alcance pleno aos 45 s do GDMD"): return
	brain.age = 500.0
	if not _check(brain.hunt_scale() == 1.0, "depois disso fica em 1"): return
	brain.free()

	# Partida: o bot envelhece só enquanto corre, e nasce calmo
	var match_node: Node = load("res://scenes/match.tscn").instantiate()
	match_node.get_node("MatchSetup").skip_ceremony = true
	match_node.get_node("MatchSetup").bot_count = 1
	root.add_child(match_node)
	await root.get_node("EventBus").match_started
	for i in 30:
		await process_frame
	var bot = match_node.get_node("Main/Runner2/Steering")
	if not _check(bot != null, "o bot existe"): return
	if not _check(bot.age > 0.0 and bot.age < 10.0, "o bot começa a contar a idade (%f)" % bot.age): return
	if not _check(bot.hunt_scale() == 0.0, "e segue calmo no começo"): return
	print("OK smoke_calm_start")
	quit(0)
