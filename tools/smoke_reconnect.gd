extends SceneTree
## Teste de fumaça do Passo 27 (cap. 04 parte 04, reconexão), lado do SERVIDOR: quem cai fica em espera limitada,
## volta só com o token da própria sessão (nenhum login novo toma uma sessão ativa, errada ou expirada), recebe o
## estado completo, não ganha invulnerabilidade nem pausa a partida; passada a janela, é eliminado. Tudo fica no registro.
## Uso: godot_console --headless --path . -s res://tools/smoke_reconnect.gd

var _match: Node
var _server: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	root.add_child(_match)
	_server = load("res://scripts/network/match_server.gd").new()
	_match.add_child(_server)
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


func _steer(seq: int, value: float) -> Dictionary:
	return {"type": "steer", "seq": seq, "steer": value}


func _runner(civ: int) -> Node:
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == civ:
			return r
	return null


func _until(condition: Callable, seconds: float) -> bool:
	var limit := _time + seconds
	while not condition.call():
		if _time > limit:
			return false
		await process_frame
	return true


func _run() -> void:
	var bus: Node = root.get_node("EventBus")
	await bus.match_started
	for i in 10:
		await process_frame
	var territory: Object = root.get_node("Services").territory
	var log_ref: RefCounted = _server.net_log
	_server.reconnect_window = 3.0
	var runner := _runner(2)
	var driver: Node

	# Entrada: cada sessão recebe um token secreto e único
	if not _check(_server.join(100, 2) and _server.join(200, 1), "peers 100 (civ 2) e 200 (civ 1) devem entrar"): return
	var token2: String = _server.token_of(2)
	var token1: String = _server.token_of(1)
	if not _check(token2.length() >= 32 and token1.length() >= 32 and token1 != token2, "tokens longos e diferentes por sessão"): return
	driver = runner.get_node("Steering")

	# Sessão ATIVA não é tomada por login novo, nem com o token certo
	var r: Dictionary = _server.resume(300, token2)
	if not _check(not r.ok and r.reason == "sessao_ativa", "sessão ativa não pode ser tomada"): return
	if not _check(_server.peer_of(2) == 100 and log_ref.count("sessao_ativa") == 1, "dono continua o peer 100 e a tentativa fica no registro"): return

	# Queda: espera limitada, corredor reto, partida segue, vida NÃO é protegida
	_server.handle_command(100, _steer(1, 1.0))
	var left_before: int = _server.snapshot().left
	_server.peer_left(100)
	_server.peer_left(100)   # queda repetida: ignorada
	_server.peer_left(999)   # quem nunca entrou: ignorado
	if not _check(_server.is_waiting(2) and log_ref.count("peer_desconectado") == 1, "queda registrada uma vez, sessão em espera"): return
	if not _check(is_equal_approx(driver.get_steer(), 0.0), "sem jogador, o corredor segue reto"): return
	runner.get_node("Health").shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	runner.get_node("Health").take_damage(4)
	if not _check(await _until(func(): return _server.snapshot().left < left_before, 3.0), "o relógio da partida não para por causa da queda"): return

	# Token errado / peer já vinculado: recusado, sessão em espera intocada
	r = _server.resume(101, "0123456789abcdef0123456789abcdef")
	if not _check(not r.ok and r.reason == "token_invalido", "token errado recusado"): return
	r = _server.resume(101, 12345)
	if not _check(not r.ok and r.reason == "token_invalido", "token que nem é texto recusado"): return
	r = _server.resume(200, token2)
	if not _check(not r.ok and r.reason == "peer_ja_vinculado", "peer de outra sessão não pode assumir esta"): return
	if not _check(_server.is_waiting(2) and _server.peer_of(2) == 100, "recusas não mexem na sessão em espera"): return

	# Volta válida: estado completo
	r = _server.resume(101, token2)
	if not _check(r.ok, "token certo deve reconectar"): return
	var state: Dictionary = r.state
	if not _check(state.civ == 2 and state.window == 3.0 and state.token != token2 and state.token.length() >= 32, "estado traz civ, janela e token NOVO"): return
	if not _check(state.players.size() == 2 and state.left > 0 and state.state == 3 and state.ack == -1, "estado traz jogadores, relógio, fase e ack"): return
	if not _check(state.territory.size() == territory.cell_count, "estado traz o mapa de territórios inteiro (%d células)" % state.territory.size()): return
	if not _check(state.bonuses.has(1) and state.bonuses.has(2) and is_equal_approx(state.bonuses[2].speed, 1.0) and state.bonuses[2].has("shield"), "estado traz os bônus ativos de cada corredor"): return
	var mine: Dictionary = state.players.filter(func(p: Dictionary) -> bool: return p.id == 2)[0]
	if not _check(mine.hp < 16 and mine.alive, "a vida perdida na ausência continua perdida (sem invulnerabilidade)"): return
	if not _check(log_ref.count("reconexao_aceita") == 1, "volta registrada"): return

	# Controle devolvido: o peer novo comanda, o velho não, o token usado não vale de novo
	if not _check(_server.peer_of(2) == 101 and not _server.has_peer(100) and not _server.is_waiting(2), "sessão passou ao peer 101"): return
	if not _check(not _server.handle_command(100, _steer(2, 1.0)), "peer antigo não comanda mais"): return
	if not _check(_server.handle_command(101, _steer(1, -1.0)) and is_equal_approx(driver.get_steer(), -1.0), "peer novo comanda (numeração recomeça em 1)"): return
	_server.peer_left(101)
	r = _server.resume(102, token2)
	if not _check(not r.ok and r.reason == "token_invalido", "token já usado não vale de novo"): return

	# Reconexões repetidas não pausam a partida nem dão vantagem
	var token: String = state.token
	var peer := 101
	left_before = _server.snapshot().left
	for i in 3:
		r = _server.resume(peer + 1, token)
		if not _check(r.ok, "volta %d deve ser aceita" % (i + 1)): return
		token = r.state.token
		peer += 1
		_server.peer_left(peer)
	r = _server.resume(peer + 1, token)
	peer += 1
	if not _check(r.ok and log_ref.count("reconexao_aceita") == 5, "5 voltas registradas"): return
	if not _check(_server.snapshot().left <= left_before and _server.snapshot().state == 3, "a partida seguiu em PLAYING com o relógio andando"): return

	# Passou da janela: eliminado (a civilização 1 nunca voltou)
	_server.reconnect_window = 0.5
	var out := [false]
	bus.civilization_eliminated.connect(func(id: int): if id == 1: out[0] = true)
	_server.peer_left(200)
	if not _check(_server.is_waiting(1), "civilização 1 em espera"): return
	if not _check(await _until(func(): return out[0], 3.0), "janela esgotada deve eliminar a civilização 1"): return
	if not _check(not _server.is_waiting(1) and log_ref.count("reconexao_expirada") == 1, "expiração registrada"): return
	r = _server.resume(400, token1)
	if not _check(not r.ok and r.reason == "sessao_expirada", "sessão expirada não volta"): return
	var civ1: Dictionary = _server.snapshot().players.filter(func(p: Dictionary) -> bool: return p.id == 1)[0]
	if not _check(not civ1.alive and civ1.hp == 0, "snapshot marca a civilização 1 como eliminada"): return
	print("OK")
	quit(0)
