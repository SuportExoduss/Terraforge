extends SceneTree
## Teste de fumaça do Passo 28 (cap. 04 parte 05, tratamento de erros e recuperação), lado do SERVIDOR:
## perda de pacotes (lacunas na numeração não derrubam ninguém), dessincronização (estado oficial reenviado, com limite
## de pedidos), checkpoint periódico com checksum (corrompido/truncado/ausente/inválido é recusado e registrado,
## o válido restaura relógio, vidas, bônus, posições e territórios) e SEGURANÇA: nenhum erro duplica vidas ou bônus,
## altera territórios nem modifica o ranking.
## Uso: godot_console --headless --path . -s res://tools/smoke_recover.gd

const CHK := "user://smoke_recover.chk"
const BAD := "user://smoke_recover_bad.chk"

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# O que NENHUM erro pode alterar: territórios, ranking, vidas e bônus.
func _integrity() -> Dictionary:
	var territory: Object = root.get_node("Services").territory
	territory._wait_idle()
	var hp := {}
	var bonus := {}
	for r in get_nodes_in_group("runners"):
		var id: int = r.get_node("Civilization").id
		var health: Node = r.get_node("Health")
		hp[id] = health.points
		bonus[id] = [r.speed_multiplier, r.freeze_multiplier, r.slow_multiplier, health.shield_left]
	return {"owners": territory.owners_snapshot(), "ranking": _server.snapshot().ranking, "hp": hp, "bonus": bonus}


func _run() -> void:
	await root.get_node("EventBus").match_started
	await _frames(10)
	var services: Node = root.get_node("Services")
	var territory: Object = services.territory
	var log_ref: RefCounted = _server.net_log
	if not _check(_server.join(100, 2) and _server.join(200, 1), "peers 100 (civ 2) e 200 (civ 1) devem entrar"): return

	# --- Perda de pacotes: lacunas na numeração são normais; só repetido/atrasado é descartado
	if not _check(_server.handle_command(100, _steer(1, 1.0)) and _server.handle_command(100, _steer(5, -1.0)), "lacuna 1 -> 5 é aceita (pacotes perdidos)"): return
	if not _check(not _server.handle_command(100, _steer(3, 1.0)), "o 3 chegou atrasado: descartado"): return
	if not _check(_server.handle_command(100, _steer(9, 0.5)) and _server.snapshot_for(100).ack == 9, "lacuna 5 -> 9 aceita e o ack acompanha o último aplicado"): return
	if not _check(log_ref.count("seq_antigo") == 1, "o atrasado ficou no registro"): return

	# --- Dessincronização: o servidor reenvia o estado oficial; pedidos em excesso são recusados
	_server.resync_interval = 0.3
	var r: Dictionary = _server.resync(100)
	if not _check(r.ok and r.state.civ == 2 and r.state.ack == 9 and r.state.territory.size() == territory.cell_count, "resync devolve o estado oficial completo"): return
	if not _check(r.state.token == _server.token_of(2), "resync não troca o token (a sessão é a mesma)"): return
	var r2: Dictionary = _server.resync(100)
	if not _check(not r2.ok and r2.reason == "resync_excessivo", "pedido seguido é recusado"): return
	if not _check(not _server.resync(999).ok, "quem não está na partida não recebe estado"): return
	if not _check(log_ref.count("dessincronizacao") == 1 and log_ref.count("resync_excessivo") == 1, "pedido atendido e excesso ficam no registro"): return
	await create_timer(0.4).timeout
	if not _check(_server.resync(100).ok, "passado o intervalo, o pedido volta a ser atendido"): return

	# --- Checkpoint: estado de referência com bônus ativos
	var runner := _runner(2)
	runner.speed_multiplier = 1.5
	runner.get_node("Health").shield_left = 5.0
	runner.get_node("Health").points = 11
	await _frames(10)
	var saved: Dictionary = _server.official_state()
	if not _check(_server.save_checkpoint(CHK) == OK and FileAccess.file_exists(CHK), "checkpoint deve ser gravado"): return
	var read: Dictionary = load("res://scripts/network/match_checkpoint.gd").read(CHK)
	if not _check(not read.is_empty() and read.territory == saved.territory and read.players.size() == 2 and read.left == saved.left, "checkpoint lido confere com o salvo"): return

	# --- Checkpoint ruim é recusado e nada muda: 1 byte trocado, truncado, ausente, valores impossíveis
	var bytes := FileAccess.get_file_as_bytes(CHK)
	var flipped := bytes.duplicate()
	flipped[flipped.size() / 2] ^= 0xFF
	var f := FileAccess.open(BAD, FileAccess.WRITE)
	f.store_buffer(flipped)
	f.close()
	var before := _integrity()
	if not _check(not _server.restore_checkpoint(BAD), "arquivo com 1 byte trocado deve ser recusado"): return
	f = FileAccess.open(BAD, FileAccess.WRITE)
	f.store_buffer(bytes.slice(0, bytes.size() / 2))
	f.close()
	if not _check(not _server.restore_checkpoint(BAD), "arquivo truncado deve ser recusado"): return
	if not _check(not _server.restore_checkpoint("user://nao_existe.chk"), "arquivo ausente deve ser recusado"): return
	if not _check(log_ref.count("checkpoint_corrompido") == 2 and log_ref.count("checkpoint_ausente") == 1, "recusas ficam no registro"): return
	var wrong := saved.duplicate(true)
	wrong.players[0].hp = 999
	load("res://scripts/network/match_checkpoint.gd").write(wrong, BAD)   # checksum válido, conteúdo impossível
	if not _check(not _server.restore_checkpoint(BAD) and log_ref.count("checkpoint_invalido") == 1, "valores impossíveis são recusados mesmo com checksum válido"): return
	wrong = saved.duplicate(true)
	wrong.territory[7] = 200
	load("res://scripts/network/match_checkpoint.gd").write(wrong, BAD)
	if not _check(not _server.restore_checkpoint(BAD) and log_ref.count("checkpoint_invalido") == 2, "dono de território inexistente é recusado"): return
	var after := _integrity()
	if not _check(after == before, "checkpoints recusados não mexem em território, ranking, vidas nem bônus"): return

	# --- Restauração (servidor reiniciado): relógio, vidas, bônus, posição e territórios voltam ao salvo
	var base_dir: Vector3 = (services.home_bases[1].position - services.planet.center).normalized()
	territory.claim_cap(2, base_dir, 0.4)   # a civilização 2 "invade" a base da 1
	runner.get_node("Health").points = 3
	runner.speed_multiplier = 3.0
	runner.get_node("Health").shield_left = 0.0
	await _frames(10)
	if not _check(territory.owners_snapshot() != saved.territory, "pré-condição: o mapa mudou depois do checkpoint"): return
	if not _check(_server.restore_checkpoint(CHK), "checkpoint válido deve restaurar"): return
	var now: PackedByteArray = territory.owners_snapshot()
	var diffs := 0
	for i in now.size():
		if saved.territory[i] != 0 and now[i] != saved.territory[i]:
			diffs += 1
	if not _check(diffs == 0, "todo território que tinha dono voltou ao dono salvo (%d divergentes)" % diffs): return
	var health: Node = runner.get_node("Health")
	var saved_hp: int = saved.players.filter(func(p: Dictionary) -> bool: return p.id == 2)[0].hp
	var saved_shield: float = saved.bonuses[2].shield
	if not _check(health.points == saved_hp and is_equal_approx(health.shield_left, saved_shield) and saved_shield > 4.0, "vida (%d) e escudo (%.2f) voltaram aos valores salvos" % [saved_hp, saved_shield]): return
	if not _check(is_equal_approx(runner.speed_multiplier, 3.0), "bônus temporizado NÃO é recriado pelo restore (sem o timer ele nunca expiraria)"): return
	var mine: Dictionary = saved.players.filter(func(p: Dictionary) -> bool: return p.id == 2)[0]
	if not _check(runner.global_position.distance_to(mine.pos) < 0.001, "o corredor voltou à posição salva"): return
	if not _check(absi(_server.snapshot().left - saved.left) <= 1, "o relógio voltou ao salvo"): return
	if not _check(log_ref.count("partida_restaurada") == 1, "a restauração fica no registro"): return
	# Restaurar de novo não duplica nada
	if not _check(_server.restore_checkpoint(CHK) and health.points == saved_hp and is_equal_approx(health.shield_left, saved_shield) and is_equal_approx(runner.speed_multiplier, 3.0), "restaurar duas vezes não duplica vidas, escudo nem bônus"): return

	# --- Salvamento periódico
	_server.checkpoint_path = CHK
	_server.checkpoint_interval = 0.3
	var count: int = _server.checkpoints_saved
	await create_timer(1.0).timeout
	if not _check(_server.checkpoints_saved >= count + 2, "o servidor salva sozinho a cada intervalo (%d)" % (_server.checkpoints_saved - count)): return
	_server.checkpoint_path = ""
	if not _check(not load("res://scripts/network/match_checkpoint.gd").read(CHK).is_empty(), "o arquivo salvo sozinho é válido"): return

	# --- Segurança: lixo, quedas/voltas, resync em rajada e checkpoints ruins, tudo SÍNCRONO (nada muda de fora)
	before = _integrity()
	for junk: Variant in [null, 5, "x", [], {}, {"type": "claim_territory", "cells": [1]}, {"type": "steer", "seq": "a", "steer": 1}, {"type": "steer", "seq": 99, "steer": INF}]:
		_server.handle_command(100, junk)
	var token: String = _server.token_of(2)
	var peer := 100
	for i in 3:
		_server.peer_left(peer)
		var back: Dictionary = _server.resume(peer + 1, token)
		peer += 1
		token = back.state.token
	for i in 30:
		_server.resync(peer)
	_server.restore_checkpoint(BAD)
	_server.restore_checkpoint("user://nao_existe.chk")
	after = _integrity()
	if not _check(after.owners == before.owners, "nenhum erro alterou os territórios"): return
	if not _check(after.ranking == before.ranking, "nenhum erro modificou o ranking"): return
	if not _check(after.hp == before.hp, "nenhum erro duplicou nem tirou vidas"): return
	if not _check(after.bonus == before.bonus, "nenhum erro duplicou bônus"): return
	DirAccess.remove_absolute(CHK)
	DirAccess.remove_absolute(BAD)
	print("OK")
	quit(0)
