extends SceneTree
## Teste de fumaça do Passo 76 (SYS-003 "perder uma vida deve causar tensão", DD-021): com 4 pontos ou menos (só o último
## coração) a HUD pulsa o coração e o áudio toca um batimento; com 5 ou mais, nada; "Reduzir movimento" (Passo 56) para o
## pulso mas não o som; curar desfaz o pulso e o batimento.
## Uso: godot_console --headless --path . -s res://tools/smoke_last_heart.gd

var _match: Node
var _bus: Node
var _time := 0.0
var _segment: ColorRect


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 40.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)


# Observa o alfa do 1º quadrante do 1º coração por `seconds`; devolve [mínimo, máximo].
func _sample(seconds: float) -> Array:
	var lo := 2.0
	var hi := -1.0
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		lo = minf(lo, _segment.modulate.a)
		hi = maxf(hi, _segment.modulate.a)
	return [lo, hi]


func _run() -> void:
	await _bus.match_started
	for i in 5:
		await process_frame
	_segment = _match.get_node("Hud").find_child("Hearts", true, false).get_child(0) as ColorRect
	var audio: Node = _match.get_node("Audio")
	var settings = load("res://scripts/core/settings.gd")
	var health: Node
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == 1:
			health = r.get_node("Health")
	_check(health != null, "corredor do jogador não achado")
	health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	health.seconds_per_regen_point = 100000.0   # o campo de força não cura no meio da amostra

	# 1. Vida cheia e 5 pontos (ainda 2 corações): sem pulso, sem batimento
	audio.played.clear()
	var r: Array = await _sample(0.5)
	_check(r == [1.0, 1.0], "vida cheia não pulsa: %s" % [r])
	health.take_damage(11)   # sobram 5
	_check(health.points == 5, "esperava 5 pontos (%d)" % health.points)
	r = await _sample(1.2)
	_check(r == [1.0, 1.0] and not audio.played.has("heartbeat"), "5 pontos ainda não é risco: %s %s" % [r, audio.played])

	# 2. 4 pontos: o coração pulsa e o batimento toca
	health.shield_left = 0.0
	health.take_damage(1)
	_check(health.points == 4, "esperava 4 pontos (%d)" % health.points)
	audio.played.clear()
	r = await _sample(1.2)   # mais de um período (0,9 s)
	_check(r[1] - r[0] > 0.2, "com 4 pontos o coração deveria pulsar: %s" % [r])
	_check(audio.played.count("heartbeat") >= 1, "com 4 pontos deveria bater: %s" % [audio.played])

	# 3. Reduzir movimento: pulso para (1,0 fixo), o batimento segue
	settings.set_value("reduce_motion", 1.0, false)
	audio.played.clear()
	r = await _sample(1.2)
	settings.set_value("reduce_motion", 0.0, false)
	_check(r == [1.0, 1.0], "com Reduzir movimento o coração não pulsa: %s" % [r])
	_check(audio.played.count("heartbeat") >= 1, "com Reduzir movimento o som segue: %s" % [audio.played])

	# 4. Último ponto continua em risco; curar desfaz pulso e batimento
	health.shield_left = 0.0
	health.take_damage(3)
	_check(health.points == 1, "esperava 1 ponto (%d)" % health.points)
	r = await _sample(1.2)
	_check(r[1] - r[0] > 0.2, "com 1 ponto o coração pulsa: %s" % [r])
	health.heal(16)
	audio.played.clear()
	r = await _sample(1.2)
	_check(r == [1.0, 1.0] and not audio.played.has("heartbeat"), "curado: sem pulso nem batimento: %s %s" % [r, audio.played])
	print("OK")
	quit(0)
