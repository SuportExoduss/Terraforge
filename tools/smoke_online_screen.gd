extends SceneTree
## Teste de fumaça do Passo 46 (tela ONLINE): porta/endereço inválidos são recusados sem conectar; com um servidor dedicado
## de verdade a tela mostra "Na sala: 1 de 3" e o tempo, sair da sala volta ao estado inicial e libera a vaga no servidor,
## entrar de novo e esperar o lobby fechar mostra a civilização entregue, VOLTAR fecha a tela; o menu tem o botão ONLINE.
## Uso: godot_console --headless --path . -s res://tools/smoke_online_screen.gd

const PORT := 24686
const TEST_PROFILE := "user://profile_smoke_online.json"

var _time := 0.0


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
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
	ds.capacity = 3
	ds.max_wait = 4.0
	ds.skip_ceremony = true
	root.add_child(ds)
	await process_frame
	var lobby: Node = ds.lobby

	var screen = load("res://scripts/ui/online_screen.gd").new()
	root.add_child(screen)
	await process_frame
	if not _check(screen.title_text == "ONLINE" and screen.join.text == "ENTRAR NA SALA", "tela abre pronta para entrar"): return
	if not _check(screen.address.text == "127.0.0.1" and screen.port.text == str(ds.DEFAULT_PORT), "endereço e porta padrão"): return

	# Entradas inválidas: não conecta
	screen.port.text = "abc"
	screen.join.pressed.emit()
	if not _check(screen.net == null and screen.status.text.contains("Porta inválida"), "porta que não é número é recusada"): return
	screen.port.text = "80"
	screen.join.pressed.emit()
	if not _check(screen.net == null and screen.status.text.contains("Porta inválida"), "porta fora de 1024–65535 é recusada"): return
	screen.port.text = str(PORT)
	screen.address.text = "  "
	screen.join.pressed.emit()
	if not _check(screen.net == null and screen.status.text.contains("endereço"), "endereço vazio é recusado"): return

	# Entra na sala de verdade
	screen.address.text = "127.0.0.1"
	screen.join.pressed.emit()
	if not _check(screen.net != null and screen.join.text == "SAIR DA SALA" and screen.status.text.contains("Conectando"), "ENTRAR conecta e vira SAIR DA SALA"): return
	if not _check(await _until(func(): return screen.status.text.contains("Na sala: 1 de 3")), "a tela mostra a sala: 1 de 3"): return
	if not _check(screen.status.text.contains("a partida abre em"), "a tela mostra o tempo que falta"): return
	if not _check(lobby.peers.size() == 1, "o servidor tem 1 jogador na sala"): return

	# Sai da sala: estado inicial e a vaga volta
	screen.join.pressed.emit()
	if not _check(screen.net == null and screen.join.text == "ENTRAR NA SALA" and screen.status.text.contains("saiu"), "SAIR DA SALA desconecta"): return
	if not _check(await _until(func(): return lobby.peers.is_empty()), "o servidor libera a vaga"): return

	# Entra de novo e espera o lobby fechar pelo tempo: a tela mostra a civilização entregue
	screen.join.pressed.emit()
	if not _check(await _until(func(): return lobby.peers.size() == 1), "volta para a sala"): return
	if not _check(await _until(func(): return screen.status.text.contains("civilização"), 20.0), "lobby fechado: a tela mostra a civilização entregue"): return

	# VOLTAR fecha a tela e larga a conexão
	var closed := [false]
	screen.closed.connect(func(): closed[0] = true)
	screen.back.pressed.emit()
	if not _check(closed[0] and screen.net == null, "VOLTAR emite closed e desconecta"): return
	screen.queue_free()
	ds.queue_free()
	await process_frame

	# Menu: o botão ONLINE abre a tela e VOLTAR a fecha
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var dock_button = menu.get_node_or_null("Box/Dock/Online")
	if not _check(dock_button != null, "menu tem o botão ONLINE"): return
	dock_button.pressed.emit()
	await process_frame
	var opened = menu.get_node_or_null("Screen")
	if not _check(opened != null and opened.title_text == "ONLINE", "o botão abre a tela ONLINE"): return
	opened.back.pressed.emit()
	await process_frame
	await process_frame
	if not _check(menu.get_node_or_null("Screen") == null, "VOLTAR fecha a tela"): return
	menu.queue_free()

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_online_screen")
	quit(0)
