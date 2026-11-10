extends SceneTree
## Teste de fumaça do Passo 52 (CRIAR SALA, Cap.04 lobby): o botão sobe um servidor dedicado de 2 vagas num processo à parte
## e entra nele; porta inválida não sobe nada; SAIR e CANCELAR encerram o processo (nada de servidor órfão).
## Uso: godot_console --headless --path . -s res://tools/smoke_online_host.gd

const PORT := 24691
const TEST_PROFILE := "user://profile_smoke_host.json"

var _time := 0.0
var _pid := 0   # o servidor aberto pela tela (para limpar se o teste falhar)


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 90.0:
		print("FALHOU: tempo esgotado")
		_cleanup()
		quit(1)
	return false


func _cleanup() -> void:
	if _pid > 0:
		OS.kill(_pid)
	DirAccess.remove_absolute(TEST_PROFILE)


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		_cleanup()
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
	profile.path = TEST_PROFILE   # a tela grava a sala ao entrar: não mexe no perfil real
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	var screen = load("res://scripts/ui/online_screen.gd").new()
	root.add_child(screen)
	await process_frame
	if not _check(screen.host_button != null and screen.host_button.visible, "a tela tem o botão CRIAR SALA"): return

	# Porta inválida: nada sobe
	screen.port.text = "abc"
	screen.host_button.pressed.emit()
	if not _check(screen._server_pid == 0 and screen.net == null, "porta inválida não abre sala"): return

	# CRIAR SALA: o processo sobe e a tela entra nele
	screen.port.text = str(PORT)
	screen.host_button.pressed.emit()
	_pid = screen._server_pid
	if not _check(_pid > 0 and OS.is_process_running(_pid), "o servidor local está rodando"): return
	if not _check(not screen.host_button.visible and screen.join.text == "CANCELAR", "enquanto abre: só dá para cancelar"): return
	if not _check(await _until(func(): return screen.net != null and screen.net.is_online(), 40.0), "a tela entrou na sala criada"): return
	if not _check(await _until(func(): return not screen._info.is_empty(), 5.0), "a sala informa seu estado"): return
	if not _check(screen._info.capacity == 2 and screen._info.humans == 1, "sala de 2 vagas com 1 jogador (eu)"): return
	if not _check(screen.join.text == "SAIR DA SALA" and not screen.host_button.visible, "dentro da sala: SAIR, sem CRIAR"): return

	# SAIR fecha a sala (o processo termina)
	screen.join.pressed.emit()
	if not _check(screen._server_pid == 0 and screen.host_button.visible and screen.join.text == "ENTRAR NA SALA", "saiu: a tela volta ao normal"): return
	if not _check(await _until(func(): return not OS.is_process_running(_pid), 5.0), "sair encerra o servidor local"): return

	# CANCELAR enquanto a sala ainda sobe também encerra o processo
	screen.host_button.pressed.emit()
	_pid = screen._server_pid
	if not _check(_pid > 0 and screen.net == null, "criou de novo (ainda subindo)"): return
	screen.join.pressed.emit()
	if not _check(screen._server_pid == 0 and screen.host_button.visible and screen.join.text == "ENTRAR NA SALA", "cancelou: a tela volta ao normal"): return
	if not _check(await _until(func(): return not OS.is_process_running(_pid), 5.0), "cancelar encerra o servidor local"): return
	for i in 130:   # os 2 s do cronômetro de entrada passam sem tentar conectar nem dar erro
		await process_frame

	screen.queue_free()
	await process_frame
	_pid = 0
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_online_host")
	quit(0)
