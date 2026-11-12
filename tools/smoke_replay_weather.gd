extends SceneTree
## Teste de fumaça do Passo 85 (Cap.03 P11 REPLAY "mudanças climáticas"): o clima avisa quando a janela muda (sinal novo
## `weather_changed`, uma vez por mudança, nunca repetido); o replay anota essas mudanças e escreve o clima na legenda
## ("REPLAY 2:10 · CHUVA") só enquanto ele durou, sem legenda de clima quando o céu está limpo.
## Uso: godot_console --headless --path . -s res://tools/smoke_replay_weather.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
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


func _run() -> void:
	await _bus.match_started
	await process_frame
	var services: Node = root.get_node("Services")
	var flow: Node = services.flow
	var replay: Node = _match.get_node("MatchReplay")
	var weather: Node = _match.get_node("Weather")
	var director: Script = load("res://scripts/world/weather_manager.gd")
	var timer: Node = _match.get_node("MatchTimer")
	timer.set_process(false)   # o relógio real não pode sobrescrever os segundos que o teste emite
	services.territory.claim_cap(1, Vector3(0.0, -0.9, 0.4).normalized(), 0.4)
	for i in 5:
		await process_frame

	# Uma semente cuja janela 1 não seja limpa (cada semente sorteia o clima de um jeito)
	var seed_value := 1
	while director.condition_for(seed_value, 1) == "clear":
		seed_value += 1
	weather.weather_seed = seed_value
	var picked: String = director.condition_for(seed_value, 1)
	var label: String = director.LABELS[picked]
	var duration: float = timer.duration_seconds
	var length: float = duration / director.WINDOWS

	var seen := []
	_bus.weather_changed.connect(func(condition: String) -> void: seen.append(condition))

	# O sinal sai uma vez por mudança: entra na janela 1, fica nela (nada), volta para a 0 (limpa)
	replay._clock = 100.0
	_bus.match_clock_changed.emit(int(duration - 1.5 * length))
	await process_frame
	await process_frame
	_bus.match_clock_changed.emit(int(duration - 1.6 * length))
	await process_frame
	await process_frame
	if not _check(seen == [picked], "entrar na janela 1 avisa uma vez: %s" % [seen]): return
	replay._clock = 300.0
	_bus.match_clock_changed.emit(int(duration - 0.5 * length))
	await process_frame
	await process_frame
	if not _check(seen == [picked, "clear"], "voltar ao céu limpo avisa: %s" % [seen]): return
	var noted: Array = replay._weather   # o relógio do replay corre sozinho: confere condição e instante aproximado
	if not _check(noted.size() == 3 and noted[1][1] == picked and absf(noted[1][0] - 100.0) < 1.0 and noted[2][1] == "clear" and absf(noted[2][0] - 300.0) < 1.0, "o replay anotou o clima: %s" % [noted]): return

	# Replay de 1 s para uma partida de 400 s: o clima dura do instante 100 ao 300 = de 0,25 s a 0,75 s do replay
	replay._clock = 400.0
	flow.time_up_seconds = 0.0
	flow.tally_seconds = 0.0
	flow.replay_seconds = 1.0
	_bus.match_ended.emit()
	if not _check(replay.playing and not replay._caption.text.contains(label), "no começo o céu está limpo (%s)" % replay._caption.text): return
	await create_timer(0.5).timeout
	if not _check(replay._caption.text.contains(label), "no meio a legenda diz o clima %s (%s)" % [label, replay._caption.text]): return
	await create_timer(0.4).timeout
	if not _check(replay.playing and not replay._caption.text.contains(label), "perto do fim o clima já passou (%s)" % replay._caption.text): return
	print("OK: o clima avisa a mudança (uma vez) e a legenda do replay mostra %s no trecho certo" % label)
	quit(0)
