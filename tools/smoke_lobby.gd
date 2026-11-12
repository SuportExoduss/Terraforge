extends SceneTree
## Teste de fumaça do Passo 38 (Cap.04 STATE-001…003, Cap.03 "Matchmaking", Adendo 06 servidor dedicado): (1) a sala
## (MatchLobby) abre, junta jogadores, fecha quando enche OU quando o tempo máximo de espera acaba (o relógio só corre
## com gente na sala) e diz quantos bots completam; (2) a linha de comando `--server --port --players --wait` é lida e o
## inválido cai no padrão; (3) em ENet de verdade: o servidor dedicado abre a sala, os clientes entram, veem o estado
## dela e saem, o lobby fecha pelo tempo, a partida nasce com os bots e cada humano recebe o seu corredor; quem chega
## depois do fechamento é recusado.
## Uso: godot_console --headless --path . -s res://tools/smoke_lobby.gd

const PORT := 24685

var _time := 0.0


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 180.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _side(side_name: String) -> Node:
	var side := Node.new()
	side.name = side_name
	root.add_child(side)
	set_multiplayer(SceneMultiplayer.new(), side.get_path())
	var net: Node = load("res://scripts/network/net_session.gd").new()
	net.name = "Net"
	side.add_child(net)
	return net


func _until(condition: Callable, seconds := 5.0) -> bool:
	var limit := _time + seconds
	while not condition.call():
		if _time > limit:
			return false
		await process_frame
	return true


func _lobby_logic() -> bool:
	var lobby: Node = load("res://scripts/network/match_lobby.gd").new()
	lobby.capacity = 3
	lobby.max_wait = 10.0
	var closings: Array = []
	var changes := [0]
	lobby.closed.connect(func(peers: Array, bots: int): closings.append([peers, bots]))
	lobby.changed.connect(func(): changes[0] += 1)
	var P: Dictionary = lobby.Phase
	if not _check(lobby.phase == P.SERVER_INIT and not lobby.add(1), "servidor de pé, sala ainda fechada: ninguém entra"): return false
	lobby.open()
	if not _check(lobby.phase == P.MATCHMAKING, "open() abre o matchmaking"): return false
	lobby._process(50.0)
	if not _check(lobby.phase == P.MATCHMAKING and is_equal_approx(lobby.seconds_left(), 10.0), "sala vazia não gasta a espera nem abre partida de bots"): return false
	if not _check(lobby.add(1) and not lobby.add(1), "entra uma vez só"): return false
	lobby._process(4.0)
	if not _check(is_equal_approx(lobby.seconds_left(), 6.0), "a espera corre com gente na sala"): return false
	lobby.remove(1)
	if not _check(lobby.peers.is_empty() and is_equal_approx(lobby.seconds_left(), 10.0), "sala esvaziou: a espera recomeça"): return false
	lobby.add(1)
	lobby.add(2)
	if not _check(lobby.bots() == 1, "duas pessoas numa sala de três: um bot completa"): return false
	lobby._process(9.9)
	if not _check(lobby.phase == P.MATCHMAKING and closings.is_empty(), "antes do prazo continua aberta"): return false
	lobby._process(0.2)
	if not _check(lobby.phase == P.CLOSED and closings.size() == 1 and closings[0][0] == [1, 2] and closings[0][1] == 1, "o prazo fecha o lobby: [1, 2] + 1 bot"): return false
	var before: int = changes[0]
	lobby.remove(1)
	lobby._process(100.0)
	if not _check(not lobby.add(3) and lobby.peers == [1, 2] and closings.size() == 1 and changes[0] == before, "lobby fechado é definitivo: ninguém entra, ninguém sai, não fecha de novo"): return false
	lobby.free()

	var full: Node = load("res://scripts/network/match_lobby.gd").new()
	full.capacity = 2
	var full_closings: Array = []
	full.closed.connect(func(peers: Array, bots: int): full_closings.append([peers, bots]))
	full.open()
	full.add(7)
	if not _check(full_closings.is_empty(), "meia sala não fecha"): return false
	full.add(8)
	if not _check(full.phase == P.CLOSED and full_closings == [[[7, 8], 0]], "sala cheia fecha na hora, sem bots"): return false
	full.capacity = 99
	if not _check(full.capacity == full.MAX_CAPACITY, "capacidade limitada ao máximo da partida"): return false
	full.capacity = 0
	if not _check(full.capacity == 1, "e ao mínimo de uma vaga"): return false
	full.free()
	return true


func _command_line() -> bool:
	var script: GDScript = load("res://scripts/network/dedicated_server.gd")
	if not _check(script.requested(PackedStringArray(["--headless", "--server"])) and not script.requested(PackedStringArray(["--headless"])), "--server liga o servidor dedicado"): return false
	var cfg: Node = script.new()
	cfg.configure(PackedStringArray(["--server", "--port=24999", "--players=3", "--wait=7.5"]))
	if not _check(cfg.port == 24999 and cfg.capacity == 3 and is_equal_approx(cfg.max_wait, 7.5), "porta, vagas e espera lidas da linha de comando"): return false
	var bad: Node = script.new()
	bad.configure(PackedStringArray(["--port=80", "--players=9", "--wait=-1", "--players=abc", "--port", "--wait=x", "lixo"]))
	if not _check(bad.port == script.DEFAULT_PORT and bad.capacity == 4 and is_equal_approx(bad.max_wait, 20.0), "valor inválido cai no padrão"): return false
	cfg.free()
	bad.free()
	return true


func _run() -> void:
	if not _lobby_logic() or not _command_line():
		return

	# Servidor dedicado de verdade: usa o multiplayer padrão; os clientes têm o seu próprio (_side).
	var ds: Node = load("res://scripts/network/dedicated_server.gd").new()
	ds.port = PORT
	ds.capacity = 3
	ds.max_wait = 5.0
	ds.skip_ceremony = true
	root.add_child(ds)
	await process_frame   # dentro de _initialize a árvore ainda não chamou o _ready de ninguém
	var lobby: Node = ds.lobby
	var P: Dictionary = lobby.Phase
	var matchsrv: Node = ds.net.match_server
	if not _check(lobby.phase == P.MATCHMAKING and matchsrv != null and ds.game == null, "servidor de pé com a sala aberta e sem partida"): return

	var a := _side("ClientA")
	var infos_a: Array = []
	a.lobby_updated.connect(func(info: Dictionary): infos_a.append(info))
	a.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return not infos_a.is_empty()), "A entra na sala e recebe o estado dela"): return
	var first: Dictionary = infos_a[-1]
	if not _check(first.phase == P.MATCHMAKING and first.humans == 1 and first.capacity == 3 and first.seconds_left > 0.0, "estado da sala: matchmaking, 1 de 3"): return
	if not _check(a.my_civ == 0, "na sala ainda não existe corredor"): return

	var c := _side("ClientC")   # entra e desiste: a vaga volta
	c.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return lobby.peers.size() == 2), "C entra na sala"): return
	if not _check(await _until(func(): return infos_a[-1].humans == 2), "A fica sabendo que a sala tem 2"): return
	c.close()
	if not _check(await _until(func(): return lobby.peers.size() == 1), "quem sai da sala libera a vaga"): return
	if not _check(await _until(func(): return infos_a[-1].humans == 1), "A fica sabendo que a sala voltou a 1"): return

	var b := _side("ClientB")
	b.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return lobby.peers.size() == 2), "B entra na sala"): return

	# O tempo máximo de espera fecha o lobby: a partida nasce com 3 civilizações, 2 humanas e 1 bot
	if not _check(await _until(func(): return lobby.phase == P.CLOSED, 8.0), "o tempo máximo de espera fecha o lobby"): return
	if not _check(ds.game != null and ds.game.get_node("MatchSetup").bot_count == 2, "a partida nasce com as 3 civilizações da sala"): return
	if not _check(await _until(func(): return a.my_civ != 0 and b.my_civ != 0), "lobby fechado: cada humano recebe o seu corredor"): return
	if not _check(a.my_civ == 1 and b.my_civ == 2, "na ordem de chegada (A=1, B=2; a civilização de C não existiu)"): return
	if not _check(matchsrv.peer_of(1) != 0 and matchsrv.peer_of(2) != 0 and matchsrv.free_civilization() == 3, "a 3ª civilização ficou com o bot"): return
	if not _check(infos_a[-1].phase == P.CLOSED, "o cliente soube que o lobby fechou"): return
	if not _check(await _until(func(): return not a.last_snapshot.is_empty() and not b.last_snapshot.is_empty(), 90.0), "a partida corre: os dois recebem snapshots"): return

	# Lobby fechado: quem chega depois é recusado
	var late := _side("ClientLate")
	late.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return matchsrv.net_log.count("lobby_fechado") == 1, 4.0), "quem chega depois do fechamento é recusado e registrado"): return
	if not _check(late.my_civ == 0 and lobby.peers.size() == 2, "o retardatário não ganhou corredor nem vaga"): return
	print("OK")
	quit(0)
