extends SceneTree
## Teste de fumaça do Passo 51 (latência na tela ONLINE, Cap.03 P02): sem conexão o ping é -1; conectado vira um número >= 0;
## o status da sala e o quadro da partida mostram "ping"/"Ping ... ms" (o quadro desenha sem erro).
## Uso: godot_console --headless --path . -s res://tools/smoke_online_ping.gd

const PORT := 24690

var _time := 0.0


func _initialize() -> void:
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


func _until(condition: Callable, seconds := 5.0) -> bool:
	var limit := _time + seconds
	while not condition.call():
		if _time > limit:
			return false
		await process_frame
	return true


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	profile.path = "user://profile_smoke_ping.json"   # não mexe no perfil real (a tela grava a sala ao entrar)

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
	screen.address.text = "127.0.0.1"
	screen.port.text = str(PORT)
	screen.join.pressed.emit()
	if not _check(screen.net != null and screen.net.ping_ms() == -1, "ainda conectando: ping -1"): return

	# Conectado: o ping é um número de verdade, e a sala o mostra
	if not _check(await _until(func(): return screen.net.is_online(), 10.0), "conectou"): return
	if not _check(await _until(func(): return screen.net.ping_ms() >= 0, 5.0), "conectado: ping >= 0"): return
	if not _check(await _until(func(): return screen.status.text.contains("ping ") and screen.status.text.contains(" ms"), 5.0), "a sala mostra o ping"): return

	# Partida rolando: o quadro desenha com o ping
	if not _check(await _until(func(): return screen.board != null and not screen.net.last_snapshot.is_empty(), 20.0), "a partida começou"): return
	screen.board.queue_redraw()
	for i in 3:
		await process_frame
	if not _check(screen.net.ping_ms() >= 0, "ping segue valendo durante a partida"): return

	screen.join.pressed.emit()   # sai da sala antes de largar a tela
	screen.queue_free()
	ds.queue_free()
	await process_frame
	print("OK smoke_online_ping")
	quit(0)
