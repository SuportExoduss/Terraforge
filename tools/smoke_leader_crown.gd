extends SceneTree
## Teste de fumaça do Passo 117 (coroa do líder, DD-157): quem lidera o domínio (≥ 8% e estritamente à frente do 2º) ganha a coroa
## flutuando sobre o corredor; troca de líder move a coroa; empate, líder abaixo do mínimo ou eliminado = sem coroa/passa ao próximo.
## Uso: godot_console --headless --path . -s res://tools/smoke_leader_crown.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	load("res://scripts/core/profile.gd").path = "user://profile_smoke_leader_crown.json"
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 2
	root.add_child(_match)
	_bus = root.get_node("EventBus")
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


func _scores(a: float, b: float, c: float) -> void:
	for pair in [[1, a], [2, b], [3, c]]:
		_bus.territory_score_changed.emit(pair[0], pair[1])
	await create_timer(0.6).timeout   # a coroa confere o ranking a cada 0,25 s


func _runner(id: int) -> Node3D:
	for node in get_nodes_in_group("runners"):
		if node.get_node("Civilization").id == id:
			return node
	return null


func _run() -> void:
	await _bus.match_started
	await process_frame
	var crown: Node = _match.get_node("LeaderCrown")
	var planet: Node = root.get_node("Services").planet
	for id in [1, 2, 3]:
		if not _check(_runner(id) != null, "corredor da civilização %d na cena" % id): return

	# Líder claro: coroa sobre o corredor dele, acima da cabeça
	await _scores(0.30, 0.10, 0.05)
	if not _check(crown.leader_id == 1 and crown.get_node("Crown").visible, "civ 1 lidera (id=%d)" % crown.leader_id): return
	var gap: float = (crown.get_node("Crown").global_position - _runner(1).global_position).length()
	if not _check(gap > 1.8 and gap < 3.2, "coroa acima do corredor (distância %.2f)" % gap): return

	# Troca de líder: a coroa vai para o outro corredor
	await _scores(0.30, 0.50, 0.05)
	if not _check(crown.leader_id == 2, "civ 2 assume (id=%d)" % crown.leader_id): return
	gap = (crown.get_node("Crown").global_position - _runner(2).global_position).length()
	if not _check(gap > 1.8 and gap < 3.2, "coroa seguiu para o corredor 2 (distância %.2f)" % gap): return

	# Empate no topo: ninguém coroado
	await _scores(0.40, 0.40, 0.05)
	if not _check(crown.leader_id == -1 and not crown.get_node("Crown").visible, "empate = sem coroa (id=%d)" % crown.leader_id): return

	# Líder abaixo do mínimo de 8%: ninguém coroado
	await _scores(0.05, 0.06, 0.01)
	if not _check(crown.leader_id == -1 and not crown.get_node("Crown").visible, "abaixo de 8%% = sem coroa (id=%d)" % crown.leader_id): return

	# Líder eliminado: a coroa passa a quem ficou na frente
	await _scores(0.30, 0.50, 0.05)
	_bus.civilization_eliminated.emit(2)
	await create_timer(0.6).timeout
	if not _check(crown.leader_id == 1, "eliminado perde a coroa, civ 1 assume (id=%d)" % crown.leader_id): return

	print("OK")
	quit(0)
