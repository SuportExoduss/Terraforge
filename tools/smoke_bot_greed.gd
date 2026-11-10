extends SceneTree
## Teste de fumaça do Passo 62 (Cap.05 P05 "comportamentos distintos"): cada civilização-bot nasce com uma cobiça fixa por
## id (não sorteada); a cobiça muda o alcance com que um cristal de bônus desperta o bot; a ambição do DD-130 segue sorteada.
## Uso: godot_console --headless --path . -s res://tools/smoke_bot_greed.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 2   # ids 2 (cobiça 1,5) e 3 (cobiça 0,5)
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


## Põe um cristal a 30 m à frente do bot, pergunta se ele o enxerga e tira o cristal.
func _sees_crystal_at_30m(rival: Node3D, bonuses: Node) -> bool:
	var bot: Node = rival.get_node("Steering")
	var up: Vector3 = rival.global_basis.y
	bonuses._spawn(rival.global_position + rival.forward * 30.0, up, 0)
	var seen: bool = bot._find_bonus_point()
	for pickup in get_nodes_in_group("bonus_pickups"):
		pickup.free()
	return seen


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var bonuses: Node = _match.get_node("Bonuses")
	var greedy: Node3D = _match.get_node("Main/Runner2")
	var picky: Node3D = _match.get_node("Main/Runner3")
	_match.get_node("Main/Runner").set_process(false)
	greedy.set_process(false)
	picky.set_process(false)

	# 1. Cobiça fixa por id da civilização
	if not _check(is_equal_approx(greedy.get_node("Steering").greed, 1.5), "civ 2: cobiça 1,5 (%.2f)" % greedy.get_node("Steering").greed): return
	if not _check(is_equal_approx(picky.get_node("Steering").greed, 0.5), "civ 3: cobiça 0,5 (%.2f)" % picky.get_node("Steering").greed): return

	# 2. Mesmo cristal, mesma distância: o cobiçoso (alcance 60 m) vai atrás, o desinteressado (20 m) ignora
	if not _check(_sees_crystal_at_30m(greedy, bonuses), "o cobiçoso deveria enxergar o cristal a 30 m"): return
	if not _check(not _sees_crystal_at_30m(picky, bonuses), "o desinteressado não deveria enxergar o cristal a 30 m"): return

	# 3. A ambição do DD-130 continua sorteada (a cobiça não a substitui)
	var ambitions: Array[float] = []
	for n in 20:
		ambitions.append(greedy.get_node("Steering").ambition_for(1000))
	if not _check(ambitions.min() < ambitions.max(), "a ambição deveria continuar aleatória"): return

	print("OK: cobiça por bônus fixa por civilização (2 = 1,5; 3 = 0,5) muda o alcance dos cristais; ambição segue sorteada")
	quit(0)
