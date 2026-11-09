extends SceneTree
## Teste de fumaça do Passo 50 (lembrar a sala online): a tela ONLINE nasce com o endereço/porta padrão; entradas inválidas
## não sobrescrevem nada; entrar numa sala grava endereço e porta no perfil (em disco); uma tela nova já volta preenchida.
## Uso: godot_console --headless --path . -s res://tools/smoke_online_saved.gd

const PORT := 24689
const TEST_PROFILE := "user://profile_smoke_saved.json"

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
	ds.capacity = 2
	ds.max_wait = 3.0
	ds.skip_ceremony = true
	root.add_child(ds)
	await process_frame

	var screen = load("res://scripts/ui/online_screen.gd").new()
	root.add_child(screen)
	await process_frame
	if not _check(screen.address.text == "127.0.0.1" and screen.port.text == str(ds.DEFAULT_PORT), "perfil novo: endereço e porta padrão"): return

	# Entrada inválida não grava nada
	screen.port.text = "abc"
	screen.join.pressed.emit()
	if not _check(not profile.data.has("online"), "porta inválida não é lembrada"): return

	# Entrar numa sala grava endereço e porta, na memória e em disco
	screen.address.text = " localhost "
	screen.port.text = str(PORT)
	screen.join.pressed.emit()
	if not _check(screen.net != null, "entrou (conectando)"): return
	if not _check(profile.data.get("online") == {"address": "localhost", "port": PORT}, "endereço (sem espaços) e porta ficam no perfil"): return
	profile.load_data()   # relê do disco
	if not _check(profile.data.get("online", {}).get("port") == PORT, "e ficam gravados em disco"): return
	if not _check(await _until(func(): return screen.net.my_civ != 0 or screen.status.text.contains("Partida online"), 20.0), "a sala funciona com o endereço salvo"): return
	screen.join.pressed.emit()   # sai da sala antes de largar a tela
	screen.queue_free()
	await process_frame

	# Uma tela nova volta preenchida
	var again = load("res://scripts/ui/online_screen.gd").new()
	root.add_child(again)
	await process_frame
	if not _check(again.address.text == "localhost" and again.port.text == str(PORT), "tela nova volta com a última sala"): return

	again.queue_free()
	ds.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_online_saved")
	quit(0)
