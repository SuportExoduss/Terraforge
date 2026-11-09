extends SceneTree
## Teste de fumaça do Passo 44 (DD-013, primeira conquista espetacular): só o PRIMEIRO circuito válido do jogador local
## dispara o anel + faíscas; circuito vazio, outro dono e a segunda conquista não disparam nada.
## Uso: godot_console --headless --path . -s res://tools/smoke_first_conquest.gd


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _cells(count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in count:
		out.append(Vector3(0.0, 100.0, 0.0) + Vector3(i * 0.1, 0.0, 0.0))
	return out


func _claim(bus: Node, owner: int, count: int) -> void:
	bus.territory_cells_claimed.emit(owner, _cells(count), 1.0)
	bus.territory_loop_claimed.emit(owner, count)


func _run() -> void:
	var match_node: Node = load("res://scenes/match.tscn").instantiate()
	match_node.get_node("MatchSetup").skip_ceremony = true
	match_node.get_node("MatchSetup").bot_count = 1
	root.add_child(match_node)
	var bus: Node = root.get_node("EventBus")
	await bus.match_started
	await process_frame
	var burst: Node = match_node.get_node("FirstConquest")

	_claim(bus, 1, 5)    # circuito vazio (poucas células)
	if not _check(not burst.fired and burst.get_child_count() == 0, "circuito vazio não dispara"): return
	_claim(bus, 2, 40)   # outra civilização
	if not _check(not burst.fired and burst.get_child_count() == 0, "conquista de adversário não dispara"): return

	_claim(bus, 1, 40)   # a primeira de verdade
	if not _check(burst.fired and burst.get_child_count() == 1, "primeira conquista dispara"): return
	var spot: Node = burst.get_child(0)
	if not _check(spot.get_node_or_null("Ring") is MeshInstance3D and spot.get_node_or_null("Sparks") is CPUParticles3D, "anel e faíscas existem"): return
	if not _check(spot.global_basis.y.dot(Vector3.UP) > 0.99, "o 'cima' do efeito aponta para fora do planeta"): return

	_claim(bus, 1, 40)   # a segunda não repete
	if not _check(burst.get_child_count() == 1, "segunda conquista não repete"): return

	await create_timer(burst.LIFETIME + 0.5).timeout
	if not _check(burst.get_child_count() == 0, "o efeito se apaga sozinho"): return
	print("OK smoke_first_conquest")
	quit(0)
