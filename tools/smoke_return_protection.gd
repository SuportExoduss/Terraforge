extends SceneTree
## Teste de fumaça do Passo 73 (SYS-003 RESPAWN + BALANCEAMENTO "sem sequência de eliminações sem reação"):
## ao ser devolvido ao campo de força (corte de rastro) o jogador fica 2 s sem perder pontos; o dano seguinte
## é absorvido, o corredor continua se movendo e passados os 2 s o dano volta a valer. Cortes seguidos não matam.
## Uso: godot_console --headless --path . -s res://tools/smoke_return_protection.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)


func _run() -> void:
	await _bus.match_started
	for i in 5:
		await process_frame
	var health: Node
	var runner: Node3D
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == 1:
			runner = r
			health = r.get_node("Health")
	_check(health != null, "corredor do jogador não achado")
	health.shield_left = 0.0
	var start: int = health.points

	_bus.trail_cut.emit(1, 2)   # corte: -2, volta ao campo, 2 s de proteção
	_check(health.points == start - 2, "o corte deveria tirar 2 (%d -> %d)" % [start, health.points])
	_check(health.shield_left > 1.5, "devia ter proteção ao voltar (%.2f)" % health.shield_left)
	_bus.trail_cut.emit(1, 3)   # outro corte logo em seguida: o corredor volta ao campo, mas não perde pontos
	health.take_damage(1, "VULCÃO")
	_check(health.points == start - 2, "dano durante a proteção deveria ser absorvido (%d)" % health.points)

	var before := runner.global_position
	for i in 20:
		await process_frame
	_check(runner.global_position.distance_to(before) > 0.0 or runner.is_processing(), "a proteção não pode travar o corredor")

	health.shield_left = 0.0   # passou o tempo
	health.take_damage(1, "VULCÃO")
	_check(health.points == start - 3, "sem proteção o dano volta a valer (%d)" % health.points)

	var shielded: float = health.shield_left   # a nave (base_relocated) também dá a proteção de retorno
	_bus.base_relocated.emit(1, runner.global_position)
	_check(health.shield_left > shielded + 1.5 and health.points == health.max_points, "pouso da nave: proteção e vida cheia")
	print("OK")
	quit(0)
