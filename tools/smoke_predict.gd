extends SceneTree
## Teste de fumaça do Passo 26 (cap. 04 parte 03, predição visual): o cliente prevê o próprio corredor com o MESMO passo do
## servidor (RunnerMotion), refaz os comandos pendentes a cada snapshot e dissolve as diferenças sem teletransportar.
## Planeta falso (esfera com morros) e rede simulada (atraso de 3 quadros por trecho, snapshot a cada 3 quadros): sem janela.
## Uso: godot_console --headless --path . -s res://tools/smoke_predict.gd

const DT := 1.0 / 60.0
const LAG := 3   # quadros de ida e de volta, cada

class FakePlanet:
	var center := Vector3.ZERO
	func get_surface_radius(d: Vector3) -> float:
		return 100.0 + 2.0 * sin(d.x * 6.0) * cos(d.z * 5.0)   # morros e vales leves

var _planet := FakePlanet.new()


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _start() -> Array:
	var up := Vector3.BACK
	var pos: Vector3 = _planet.center + up * (_planet.get_surface_radius(up) + 1.0)
	return [pos, Vector3.RIGHT]


func _push(state: Array, meters: float) -> void:   # o servidor leva o corredor para longe (onda, volta à base...)
	var moved := RunnerMotion.advance(state[0], state[1], 0.0, 1.0, _planet, 1.0, meters, 180.0)
	state[0] = moved[0]
	state[1] = moved[1]


# Roda `frames` quadros: cliente prevê e envia (chega ao servidor em LAG quadros), o servidor segura o último volante e anda,
# e a cada 3 quadros manda um snapshot (chega em LAG quadros). `events`: quadro -> Callable(state do servidor).
# Devolve {max_jump (maior salto visual num quadro), err (distância final cliente x previsão do servidor), client, server}.
func _simulate(frames: int, server_speed: float, events := {}, deliver_snapshots := true) -> Dictionary:
	var s := _start()
	var client := RunnerPredictor.new(_planet)
	client.reset(s[0], s[1])
	var inbox: Array = []          # comandos a caminho do servidor: {at, seq, steer}
	var snapshots: Array = []      # snapshots a caminho do cliente: {at, pos, fwd, ack}
	var held := 0.0
	var ack := -1
	var max_jump := 0.0
	var last_visual := client.visual_position()
	for i in frames:
		var steer := clampf(sin(i * 0.05) * 2.0, -1.0, 1.0)
		client.predict(i + 1, steer, DT)
		inbox.append({"at": i + LAG, "seq": i + 1, "steer": steer})
		while not inbox.is_empty() and inbox[0].at <= i:
			held = inbox[0].steer
			ack = inbox[0].seq
			inbox.pop_front()
		if events.has(i):
			events[i].call(s)
		var moved := RunnerMotion.advance(s[0], s[1], held, DT, _planet, 1.0, server_speed, 180.0)
		s[0] = moved[0]
		s[1] = moved[1]
		if i % 3 == 0:
			snapshots.append({"at": i + LAG, "pos": s[0], "fwd": s[1], "ack": ack})
		while not snapshots.is_empty() and snapshots[0].at <= i:
			var shot: Dictionary = snapshots.pop_front()
			if deliver_snapshots:
				client.reconcile(shot.pos, shot.fwd, shot.ack)
		client.update_visual(DT)
		var visual := client.visual_position()
		max_jump = maxf(max_jump, visual.distance_to(last_visual))
		last_visual = visual
	return {"max_jump": max_jump, "err": client.visual_position().distance_to(s[0]), "client": client, "server": s}


func _initialize() -> void:
	# 1. Responde NA HORA: o comando vira direção no mesmo quadro, sem esperar o servidor
	var s := _start()
	var c := RunnerPredictor.new(_planet)
	c.reset(s[0], s[1])
	var before := c.forward
	c.predict(1, 1.0, DT)
	if not _check(c.forward.angle_to(before) > 0.04 and c.pending.size() == 1, "direção deve responder no mesmo quadro e ficar pendente"): return

	# 2. Sem divergência: o cliente fica colado no que o servidor faz (a menos do atraso), sem correções visíveis
	var plain := _simulate(300, 12.0)
	print("[predict] sem divergência: salto máx %.3f, erro %.3f, pendentes %d" % [plain.max_jump, plain.err, plain.client.pending.size()])
	if not _check(plain.max_jump < 0.3, "sem divergência o movimento é contínuo (salto %.3f)" % plain.max_jump): return
	if not _check(plain.err < 1.0, "cliente perto do servidor (erro %.3f)" % plain.err): return
	if not _check(plain.client.pending.size() <= 2 * LAG + 2, "o ack descarta comandos confirmados (%d pendentes)" % plain.client.pending.size()): return

	# 3. O servidor discorda da física (Congelamento: metade da velocidade): corrige sem trancos e sem se afastar
	var slow := _simulate(300, 6.0)
	print("[predict] servidor lento: salto máx %.3f, erro %.3f" % [slow.max_jump, slow.err])
	if not _check(slow.max_jump < 0.4, "correção por divergência de física sem tranco (%.3f)" % slow.max_jump): return
	if not _check(slow.err < 2.0, "cliente não se afasta do servidor (erro %.3f)" % slow.err): return

	# 4. Diferença grande (empurrão de 5 m): reconciliação suave, nunca um salto de 5 m num quadro, e converge
	var shove := _simulate(240, 12.0, {100: func(st: Array) -> void: _push(st, 5.0)})
	print("[predict] empurrão 5 m: salto máx %.3f, deslocamento restante %.3f" % [shove.max_jump, shove.client.visual_position().distance_to(shove.client.position)])
	if not _check(shove.max_jump < 1.5, "empurrão corrigido com suavidade (salto %.3f)" % shove.max_jump): return
	if not _check(shove.client.visual_position().distance_to(shove.client.position) < 0.05, "a correção termina (sem deslocamento sobrando)"): return
	if not _check(shove.err < 1.0, "depois do empurrão o cliente está de volta ao servidor (erro %.3f)" % shove.err): return

	# 5. Necessidade real (servidor mandou o corredor a 50 m, ex.: volta à base): aí sim teletransporta
	var far := _simulate(240, 12.0, {100: func(st: Array) -> void: _push(st, 50.0)})
	if not _check(far.max_jump > 8.0, "50 m de diferença deve ser teletransporte"): return
	if not _check(far.err < 1.0 and far.client.visual_position().distance_to(far.client.position) < 0.001, "depois do teletransporte, sem correção pendente"): return

	# 6. Perda de pacotes: sem snapshots a predição segue por pouco tempo e então CONGELA (não inventa o futuro)
	var blind := _simulate(80, 12.0, {}, false)
	var mid: Vector3 = blind.client.position
	if not _check(not blind.client.is_frozen(), "com 1,3 s sem notícias ainda prevê"): return
	for i in 60:
		blind.client.update_visual(DT)
	blind.client.predict(999, 1.0, DT)
	if not _check(blind.client.is_frozen() and blind.client.position == mid, "passando de %.1f s sem snapshot a predição congela" % RunnerPredictor.MAX_BLIND_SECONDS): return
	blind.client.reconcile(blind.server[0], blind.server[1], 80)   # voltou o sinal: descongela
	if not _check(not blind.client.is_frozen(), "snapshot novo descongela"): return

	# 7. Reconexão: o estado oficial completo substitui tudo (pendentes e correções)
	blind.client.reset(s[0], s[1])
	if not _check(blind.client.pending.is_empty() and blind.client.visual_position() == s[0], "reset() recomeça do estado oficial"): return

	# 8. Latência alta alarga a tolerância: erro pequeno não vira correção visível
	var calm := RunnerPredictor.new(_planet)
	calm.latency = 0.3
	calm.reset(s[0], s[1])
	calm.reconcile(s[0] + Vector3(0.0, 0.0, 0.0) + (s[1] as Vector3) * 0.2, s[1], 0)
	if not _check(calm.visual_position().distance_to(calm.position) < 0.001 or calm.visual_position().distance_to(s[0]) < 0.001, "erro de 20 cm com latência alta: sem correção visível"): return
	print("OK")
	quit(0)
