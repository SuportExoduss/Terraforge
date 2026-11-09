extends SceneTree
## Teste de fumaça do Passo 47 (partida online no cliente): com um servidor dedicado de verdade (2 vagas, 1 humano + 1 bot),
## entrar na sala e esperar o lobby fechar abre o quadro da partida; ele recebe snapshots com a minha civilização e o ranking,
## desenha sem erro, e apertar → faz o servidor girar o MEU corredor (o quadro só pede, o servidor decide); soltar volta a 0;
## sair da sala tira o quadro e devolve o formulário.
## Uso: godot_console --headless --path . -s res://tools/smoke_online_board.gd

const PORT := 24687
const TEST_PROFILE := "user://profile_smoke_board.json"

var _time := 0.0


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		Input.action_release("ui_right")
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		Input.action_release("ui_right")
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
	if not _check(screen.board == null, "sem quadro antes de a partida começar"): return
	screen.join.pressed.emit()

	# A sala fecha por tempo e o quadro abre
	if not _check(await _until(func(): return screen.board != null, 20.0), "lobby fechado: o quadro da partida abre"): return
	var board = screen.board
	if not _check(board.net == screen.net, "o quadro usa a conexão da tela"): return
	if not _check(not screen.address.get_parent().visible, "o formulário some para dar altura ao quadro"): return

	# Snapshots chegam: minha civilização está neles, com o ranking
	if not _check(await _until(func(): return not screen.net.last_snapshot.is_empty(), 10.0), "o quadro recebe snapshots"): return
	var shot: Dictionary = screen.net.last_snapshot
	var mine: Array = shot.players.filter(func(p): return p.id == screen.net.my_civ)
	if not _check(mine.size() == 1 and shot.players.size() == 2, "o snapshot traz os 2 corredores, um deles é o meu"): return
	if not _check(shot.ranking.size() >= 1 and shot.left > 0, "o snapshot traz ranking e tempo"): return
	board.size = Vector2(400.0, 250.0)
	for i in 3:
		await process_frame   # desenha com dados de verdade (erro de desenho aparece como ERROR)

	# Direção: → no cliente vira o corredor no servidor; soltar volta a 0
	var steering = ds.net.match_server._peers.values()[0].steering
	if not _check(steering.steer == 0.0, "servidor começa sem virar"): return
	Input.action_press("ui_right")
	if not _check(await _until(func(): return steering.steer == 1.0), "→ chega ao servidor como direção 1"): return
	Input.action_release("ui_right")
	if not _check(await _until(func(): return steering.steer == 0.0), "soltar volta a direção 0"): return

	# Sair da sala tira o quadro e devolve o formulário
	screen.join.pressed.emit()
	if not _check(screen.board == null and screen.address.get_parent().visible, "SAIR DA SALA tira o quadro e devolve o formulário"): return
	screen.queue_free()
	ds.queue_free()
	await process_frame

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_online_board")
	quit(0)
