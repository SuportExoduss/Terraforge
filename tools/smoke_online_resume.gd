extends SceneTree
## Teste de fumaça do Passo 48 (queda e fim da partida online): com um servidor dedicado de verdade, o quadro da partida
## sobrevive a uma queda de conexão (a tela avisa e o NetSession volta sozinho como a mesma civilização), "PARTIDA ENCERRADA"
## aparece quando o servidor passa do tempo, e se o servidor some de vez a tela desiste, avisa e devolve o formulário.
## Uso: godot_console --headless --path . -s res://tools/smoke_online_resume.gd

const PORT := 24688
const TEST_PROFILE := "user://profile_smoke_resume.json"

var _time := 0.0


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 90.0:
		print("FALHOU: tempo esgotado")
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _until(condition: Callable, seconds := 5.0) -> bool:
	var limit := _time + seconds
	while not condition.call():
		if _time > limit:
			return false
		await process_frame
	return true


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	var ds: Node = load("res://scripts/network/dedicated_server.gd").new()
	ds.port = PORT
	ds.capacity = 2
	ds.max_wait = 3.0
	ds.skip_ceremony = true
	root.add_child(ds)
	await process_frame
	var screen = load("res://scripts/ui/online_screen.gd").new()
	root.add_child(screen)
	await process_frame
	screen.port.text = str(PORT)
	screen.join.pressed.emit()
	if not _check(await _until(func(): return screen.board != null and not screen.net.last_snapshot.is_empty(), 20.0), "a partida online abre e recebe snapshots"): return
	var civ: int = screen.net.my_civ
	var board = screen.board
	if not _check(not board.over(), "partida em andamento: sem faixa de fim"): return

	# A rede cai: o servidor derruba a conexão. A tela avisa, o quadro fica, e a volta é automática
	var old_peer: int = ds.net.match_server.peer_of(civ)
	ds.net.multiplayer.multiplayer_peer.disconnect_peer(old_peer)
	if not _check(await _until(func(): return screen.status.text.contains("Conexão perdida")), "a tela avisa que a conexão caiu"): return
	if not _check(screen.board == board and screen.net != null, "a queda não desmonta o quadro"): return
	if not _check(await _until(func(): return screen.status.text.contains("De volta à partida"), 10.0), "o cliente volta sozinho"): return
	var new_peer: int = ds.net.match_server.peer_of(civ)
	if not _check(screen.net.my_civ == civ and new_peer != 0 and new_peer != old_peer and screen.board == board, "volta como a mesma civilização, no mesmo quadro"): return

	# O servidor passa do tempo: o quadro mostra o fim
	root.get_node("Services").flow.go(5)   # MatchFlow.State.TIME_UP
	if not _check(await _until(func(): return board.over()), "o quadro percebe que a partida encerrou"): return
	await process_frame   # desenha a faixa (erro de desenho aparece como ERROR)

	# O servidor some de vez: a janela de volta esgota, a tela desiste e devolve o formulário
	screen.net.reconnect_window = 3.0
	ds.net.close()
	if not _check(await _until(func(): return screen.status.text.contains("Não foi possível voltar"), 15.0), "sem servidor a tela desiste de voltar"): return
	if not _check(await _until(func(): return screen.net == null and screen.board == null), "a tela larga a conexão e tira o quadro"): return
	if not _check(screen.join.text == "ENTRAR NA SALA" and screen.address.get_parent().visible, "o formulário volta"): return

	screen.queue_free()
	ds.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_online_resume")
	quit(0)
