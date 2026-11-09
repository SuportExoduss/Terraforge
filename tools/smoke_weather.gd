extends SceneTree
## Teste de fumaça do Passo 32 (clima, CL-002..005 / DD-086..088): (1) a condição de cada janela sai só da semente
## (igual em servidor e clientes), a 1ª janela é limpa e aurora só na metade noturna; (2) a intensidade é contínua e
## zera nas bordas das janelas (transição natural); (3) o clima aplicado respeita os tetos de legibilidade (névoa,
## chuva, aurora); (4) um evento global SOBREPÕE o clima e ele volta depois; (5) tempestade solta relâmpago.
## Uso: godot_console --headless --path . -s res://tools/smoke_weather.gd

var _match: Node
var _bus: Node
var _weather: Node
var _director: Script
var _failed := false


func _initialize() -> void:
	_director = load("res://scripts/world/weather_manager.gd")
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_weather = _match.get_node("Weather")
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


## Acha uma janela com a condição pedida para a semente da partida (-1 se não houver).
func _window_of(condition: String) -> int:
	for w in _director.WINDOWS:
		if _director.condition_for(_weather.weather_seed, w) == condition:
			return w
	return -1


func _run() -> void:
	# 1. Sorteio por semente
	var seen := {}
	for seed_value in range(1, 80):
		_check(_director.condition_for(seed_value, 0) == "clear", "a 1ª janela deve ser limpa (semente %d)" % seed_value)
		for w in _director.WINDOWS:
			var name: String = _director.condition_for(seed_value, w)
			_check(name == _director.condition_for(seed_value, w), "o sorteio deve ser determinístico")
			_check(name in ["clear", "rain", "fog", "storm", "aurora"], "condição inválida: %s" % name)
			_check(name != "aurora" or w >= _director.NIGHT_FIRST_WINDOW, "aurora de dia (semente %d, janela %d)" % [seed_value, w])
			seen[name] = true
	for name in ["rain", "fog", "storm", "aurora"]:
		_check(seen.has(name), "nenhuma semente sorteou %s" % name)

	# 2. Intensidade: contínua, 0..1, e zero nas bordas das janelas
	var length: float = 600.0 / _director.WINDOWS
	var previous := 0.0
	for second in range(0, 601):
		var state: Dictionary = _director.state_at(_weather.weather_seed, float(second), 600.0)
		var value: float = state["intensity"]
		_check(value >= 0.0 and value <= 1.0, "intensidade fora de 0..1 em %d s: %.3f" % [second, value])
		var same_window: bool = second % int(length) != 0
		_check(not same_window or absf(value - previous) < 0.12, "salto de intensidade em %d s: %.3f -> %.3f" % [second, previous, value])
		if second % int(length) == 0:
			_check(value == 0.0, "borda de janela em %d s deve ter intensidade 0 (%.3f)" % [second, value])
		previous = value
	_check(_director.state_at(_weather.weather_seed, 50.0, 600.0)["intensity"] == 0.0, "a janela 0 não tem clima")

	# 3. Aplicação no meio de cada janela com clima (tetos de legibilidade)
	await _bus.match_started
	await create_timer(0.3).timeout   # o relógio real emite o 600 inicial logo depois do GO
	_match.get_node("MatchTimer").set_process(false)   # o relógio real não pode sobrescrever os segundos que o teste emite
	var env: Environment = _match.get_node("Main/WorldEnvironment").environment
	var material: ShaderMaterial = _weather.get("_material")
	var duration: float = _match.get_node("MatchTimer").duration_seconds
	for condition in ["rain", "fog", "storm", "aurora"]:
		var w := _window_of(condition)
		if w == -1:
			continue   # esta semente não sorteou essa condição: a parte 1 já cobriu o sorteio
		_bus.match_clock_changed.emit(int(duration - (w + 0.5) * length))
		await process_frame
		await process_frame
		_check(_weather.condition == condition, "janela %d: condição %s, esperado %s" % [w, _weather.condition, condition])
		_check(_weather.intensity > 0.99, "meio da janela %d: intensidade %.3f" % [w, _weather.intensity])
		var rain: float = material.get_shader_parameter("rain")
		var aurora: float = material.get_shader_parameter("aurora")
		_check(rain <= _director.RAIN_MAX and aurora <= _director.AURORA_MAX, "chuva/aurora acima do teto")
		_check(env.fog_density <= _director.FOG_MAX + 0.00001, "névoa acima do teto: %.4f" % env.fog_density)
		_check((rain > 0.0) == (condition in ["rain", "storm"]), "%s: chuva %.2f" % [condition, rain])
		_check((aurora > 0.0) == (condition == "aurora"), "%s: aurora %.2f" % [condition, aurora])
		_check((env.fog_density > 0.0) == (condition in ["rain", "fog", "storm"]), "%s: névoa %.4f" % [condition, env.fog_density])

	# 4. Evento global sobrepõe o clima e depois ele volta
	var wet := maxi(_window_of("rain"), maxi(_window_of("fog"), _window_of("storm")))
	if wet != -1:
		_weather.override_seconds = 0.5
		_bus.match_clock_changed.emit(int(duration - (wet + 0.5) * length))
		await process_frame
		var before: float = _weather.intensity
		_check(before > 0.99, "antes do evento o clima está cheio (%.2f)" % before)
		_bus.global_event_active_changed.emit(true)
		await create_timer(0.8).timeout
		_bus.match_clock_changed.emit(int(duration - (wet + 0.5) * length))
		await process_frame
		_check(_weather.intensity < 0.01, "o evento global deve apagar o clima (%.2f)" % _weather.intensity)
		_check(env.fog_density < 0.00001, "a névoa some durante o evento (%.5f)" % env.fog_density)
		_bus.global_event_active_changed.emit(false)
		await create_timer(0.8).timeout
		_bus.match_clock_changed.emit(int(duration - (wet + 0.5) * length))
		await process_frame
		_check(_weather.intensity > 0.99, "o clima volta depois do evento (%.2f)" % _weather.intensity)

	# 5. Relâmpago
	var count: int = _weather.flashes
	_weather.strike()
	_check(_weather.flashes == count + 1, "strike() deve contar o relâmpago")
	await process_frame
	_check(material.get_shader_parameter("flash") > 0.0, "o clarão deve aparecer")
	await create_timer(0.5).timeout
	_check(material.get_shader_parameter("flash") == 0.0, "o clarão deve apagar em meio segundo")

	if not _failed:
		print("OK")
		quit(0)
