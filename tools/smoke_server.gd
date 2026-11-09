extends SceneTree
## Teste de fumaça do Passo 24 (cap. 04 parte 02, servidor autoritário): o jogador remoto só consegue PEDIR uma direção.
## Comando válido vira o volante do corredor dele; lixo (NaN, texto, tipo proibido como claim_territory, seq antigo,
## peer desconhecido, jogador eliminado) é recusado, registrado e não muda nada. O snapshot traz o estado real + ack.
## Uso: godot_console --headless --path . -s res://tools/smoke_server.gd

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


func _steer(seq: int, value: Variant) -> Dictionary:
	return {"type": "steer", "seq": seq, "steer": value}


func _runner(civ: int) -> Node:
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == civ:
			return r
	return null


func _run() -> void:
	var bus: Node = root.get_node("EventBus")
	await bus.match_started
	for i in 10:
		await process_frame
	var runner := _runner(2)
	var territory: Object = root.get_node("Services").territory

	# Entrada: um jogador por civilização, um peer por jogador, só civilização que existe
	if not _check(_server.join(100, 2), "peer 100 deve assumir a civilização 2"): return
	if not _check(not _server.join(101, 2), "civilização já tomada não pode ser dividida"): return
	if not _check(not _server.join(100, 1), "o mesmo peer não pode assumir duas civilizações"): return
	if not _check(not _server.join(102, 99), "civilização inexistente deve ser recusada"): return
	var driver: Node = runner.get_node("Steering")
	if not _check(driver.get_script().resource_path.ends_with("remote_steering.gd"), "o volante deve ser o RemoteSteering"): return

	# Comando válido manda no corredor
	var fwd_before: Vector3 = runner.forward
	if not _check(_server.handle_command(100, _steer(1, 1.0)), "steer válido deve ser aceito"): return
	for i in 20:
		await process_frame
	if not _check(runner.forward.angle_to(fwd_before) > 0.2, "o corredor deve virar com o comando do jogador remoto"): return

	# Direção fora de -1..1 é limitada, não obedecida ao pé da letra
	if not _check(_server.handle_command(100, _steer(2, 7.5)), "steer fora da faixa deve ser aceito e limitado"): return
	if not _check(is_equal_approx(driver.get_steer(), 1.0), "steer 7.5 vira 1.0"): return
	if not _check(_server.handle_command(100, _steer(3, 0.5)), "steer 0.5 deve ser aceito"): return

	# Lixo: recusado, registrado, sem mudar nada
	var owned_before: float = territory.owned_fraction(2)
	var bad: Array = [
		[100, _steer(4, NAN)], [100, _steer(4, INF)], [100, _steer(4, "esquerda")], [100, _steer(4, null)],
		[100, {"type": "steer", "seq": "5", "steer": 0.0}],
		[100, {"type": "claim_territory", "seq": 6, "cells": [1, 2, 3]}],
		[100, {"type": "set_hp", "seq": 7, "hp": 16}],
		[100, {"type": "steer", "steer": 0.0}],
		[100, "texto"], [100, null], [100, [1, 2]],
		[100, _steer(3, -1.0)],   # seq repetido
		[100, _steer(1, -1.0)],   # seq atrasado
		[999, _steer(50, -1.0)],  # peer que nunca entrou
	]
	for item: Array in bad:
		if not _check(not _server.handle_command(item[0], item[1]), "comando ruim aceito: %s" % [item[1]]): return
	if not _check(is_equal_approx(driver.get_steer(), 0.5), "nenhum comando ruim pode mexer no volante"): return
	if not _check(is_equal_approx(territory.owned_fraction(2), owned_before), "comando ruim não cria território"): return
	var log_ref: RefCounted = _server.net_log
	if not _check(log_ref.count("comando_desconhecido") == 2, "claim_territory e set_hp ficam no registro"): return
	if not _check(log_ref.count("seq_antigo") == 2, "seq repetido e atrasado ficam no registro"): return
	if not _check(log_ref.count("peer_desconhecido") == 1, "peer desconhecido fica no registro"): return

	# Snapshot: estado real da partida + o último comando aplicado a este jogador
	var shot: Dictionary = _server.snapshot_for(100)
	if not _check(shot.players.size() == 2, "snapshot traz as 2 civilizações"): return
	if not _check(shot.ack == 3, "ack = último seq aplicado (3), veio %s" % shot.ack): return
	if not _check(shot.state == 3 and shot.left > 0 and shot.tick > 0, "snapshot traz estado PLAYING, relógio e tick"): return
	for p: Dictionary in shot.players:
		if not _check(p.has_all(["id", "pos", "fwd", "hp", "alive", "dom"]), "jogador do snapshot incompleto"): return
		if not _check(p.alive and p.hp == 16, "todos vivos e com vida cheia"): return
	if not _check(_server.snapshot_for(555).ack == -1, "quem não entrou tem ack -1"): return

	# Eliminado não comanda mais
	bus.civilization_eliminated.emit(2)
	if not _check(not _server.handle_command(100, _steer(10, -1.0)), "jogador eliminado não comanda"): return
	if not _check(is_equal_approx(driver.get_steer(), 0.5), "volante do eliminado não muda"): return
	var dead: Dictionary = _server.snapshot()
	var civ2: Dictionary = dead.players.filter(func(p: Dictionary) -> bool: return p.id == 2)[0]
	if not _check(not civ2.alive, "snapshot marca a civilização 2 como eliminada"): return
	print("OK")
	quit(0)
