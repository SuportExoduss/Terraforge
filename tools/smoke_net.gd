extends SceneTree
## Teste de fumaça do Passo 25 (cap. 04 parte 03 + Adendo 06, transporte ENet): servidor e clientes conversam de verdade
## pelo ENet em 127.0.0.1 (cada lado com seu próprio MultiplayerAPI na mesma árvore). O cliente recebe a civilização,
## o comando dele vira o corredor no servidor, snapshots voltam com ack, lixo na rede é recusado, a 3ª conexão
## (partida cheia) é barrada e a queda do cliente fica registrada.
## Uso: godot_console --headless --path . -s res://tools/smoke_net.gd

const PORT := 24681

var _match: Node
var _time := 0.0
var _dt := 0.016
var _server: Node
var _a: Node
var _b: Node
var _c: Node


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	root.add_child(_match)
	_run()


func _process(delta: float) -> bool:
	_time += delta
	_dt = delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


# Um "lado" da rede: nó raiz com API própria + um NetSession chamado Net (mesmo caminho relativo nos dois lados).
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


func _runner(civ: int) -> Node:
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == civ:
			return r
	return null


func _run() -> void:
	await root.get_node("EventBus").match_started
	for i in 10:
		await process_frame

	_server = _side("ServerSide")
	if not _check(_server.host(PORT) == OK, "servidor ENet deve abrir a porta %d" % PORT): return
	_a = _side("ClientA")
	var a_connected := [false]
	_a.connected.connect(func(): a_connected[0] = true)
	if not _check(_a.connect_to("127.0.0.1", PORT) == OK, "cliente A deve iniciar a conexão"): return
	if not _check(await _until(func(): return a_connected[0]), "cliente A deve conectar"): return
	if not _check(await _until(func(): return _a.my_civ != 0), "cliente A deve receber a civilização"): return
	if not _check(_a.my_civ == 1, "A assume a primeira civilização livre (1), veio %d" % _a.my_civ): return

	# O comando do cliente vira o corredor dele no servidor
	var runner := _runner(1)
	var fwd_before: Vector3 = runner.forward
	for i in 20:
		_a.send_steer(1.0, _dt)
		await process_frame
	if not _check(runner.forward.angle_to(fwd_before) > 0.2, "o corredor da civilização 1 deve virar pelo comando de A"): return

	# Snapshots chegam ao cliente com o estado real e o ack do que o servidor aplicou
	if not _check(await _until(func(): return _a.last_snapshot.get("ack", -1) >= 20), "A deve receber snapshot com ack >= 20"): return
	var shot: Dictionary = _a.last_snapshot
	if not _check(shot.players.size() == 2 and shot.state == 3, "snapshot: 2 civilizações em PLAYING"): return

	# Predição: o corredor previsto no cliente acompanha o real do servidor (círculo de ~4 m, qualquer erro apareceria)
	if not _check(await _until(func(): return _a.predictor != null and _a.predictor.is_ready()), "A deve criar a predição no 1º snapshot"): return
	var worst := 0.0
	for i in 90:
		_a.send_steer(1.0, _dt)
		await process_frame
		if i > 30:
			worst = maxf(worst, _a.predictor.visual_position().distance_to(runner.global_position))
	print("[net] pior distância predição x servidor: %.3f m" % worst)
	if not _check(worst < 2.0, "a predição do cliente acompanha o servidor (pior %.3f m)" % worst): return
	if not _check(_a.predictor.pending.size() < 30, "o ack do servidor descarta os comandos confirmados (%d pendentes)" % _a.predictor.pending.size()): return

	# Lixo pela rede é recusado no servidor
	var driver: Node = runner.get_node("Steering")
	_a.submit.rpc_id(1, {"type": "claim_territory", "seq": 999, "cells": [1, 2]})
	_a.submit.rpc_id(1, "texto solto")
	_a.submit.rpc_id(1, {"type": "steer", "seq": 1000, "steer": NAN})
	var log_ref: RefCounted = _server.match_server.net_log
	if not _check(await _until(func(): return log_ref.count("comando_desconhecido") == 1 and log_ref.count("mensagem_invalida") == 1 and log_ref.count("direcao_invalida") == 1), "o servidor deve registrar os 3 comandos ruins"): return
	if not _check(is_equal_approx(driver.get_steer(), 1.0), "lixo na rede não mexe no volante"): return

	# 2º cliente entra na civilização 2; o 3º encontra a partida cheia e é barrado
	_b = _side("ClientB")
	if not _check(_b.connect_to("127.0.0.1", PORT) == OK, "cliente B deve iniciar a conexão"): return
	if not _check(await _until(func(): return _b.my_civ != 0), "cliente B deve receber a civilização"): return
	if not _check(_b.my_civ == 2, "B assume a civilização 2"): return
	_c = _side("ClientC")
	var c_dropped := [false]
	_c.disconnected.connect(func(): c_dropped[0] = true)
	_c.connect_to("127.0.0.1", PORT)
	if not _check(await _until(func(): return c_dropped[0]), "cliente C deve ser barrado com a partida cheia"): return
	if not _check(log_ref.count("partida_cheia") == 1, "partida cheia fica no registro"): return
	if not _check(_c.my_civ == 0, "C não recebe civilização"): return

	# Queda do cliente A: registrada e o volante zera (o corredor segue reto)
	_a.close()
	if not _check(await _until(func(): return log_ref.count("peer_desconectado") == 1), "queda de A deve ser registrada"): return
	if not _check(is_equal_approx(driver.get_steer(), 0.0), "sem jogador, o volante volta a zero"): return
	print("OK")
	quit(0)
