extends SceneTree
## Teste de fumaça do Passo 72 (SYS-003 "o jogador entende por que perdeu vida", DD-021): cada dano real do
## jogador publica damage_taken(id, pontos, causa) e a HUD escreve "-N CAUSA" sob os corações; dano de outro dono
## e dano absorvido pelo escudo não escrevem nada.
## Uso: godot_console --headless --path . -s res://tools/smoke_damage_cause.gd

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


func _cause() -> String:
	return (_match.get_node("Hud").find_child("CauseLabel", true, false) as Label).text


func _run() -> void:
	await _bus.match_started
	for i in 5:
		await process_frame
	var seen := []
	_bus.damage_taken.connect(func(id, pts, cause): seen.append([id, pts, cause]))
	var health: Node
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == 1:
			health = r.get_node("Health")
	_check(health != null, "corredor do jogador não achado")
	health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	_check(_cause() == "", "legenda deveria começar vazia: '%s'" % _cause())

	health.take_damage(1, "VULCÃO")
	_check(seen == [[1, 1, "VULCÃO"]], "sinal do vulcão: %s" % [seen])
	_check(_cause() == "-1  VULCÃO", "legenda: '%s'" % _cause())

	_bus.trail_cut.emit(1, 2)   # corte de rastro de verdade: Health tira 2 e a causa é o corte
	_check(seen.back() == [1, 2, "RASTRO CORTADO"], "corte: %s" % [seen.back()])
	_check(_cause() == "-2  RASTRO CORTADO", "legenda do corte: '%s'" % _cause())

	var before: int = seen.size()
	_bus.damage_taken.emit(2, 3, "FURACÃO")   # outro dono: HUD ignora
	_check(_cause() == "-2  RASTRO CORTADO", "dano alheio mexeu na legenda: '%s'" % _cause())

	health.grant_shield(5.0)
	health.take_damage(1, "TSUNAMI")   # absorvido: nada perdido, nada escrito
	_check(seen.size() == before + 1 and _cause() == "-2  RASTRO CORTADO", "escudo não deveria gerar aviso")

	await create_timer(2.3).timeout   # some sozinha
	_check(_cause() == "", "legenda deveria sumir: '%s'" % _cause())
	print("OK")
	quit(0)
