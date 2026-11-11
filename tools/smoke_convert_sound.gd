extends SceneTree
## Teste de fumaça do Passo 75 (SYS-002 "sons exclusivos" de cada civilização): cada uma das 6 civilizações tem um som de
## conversão próprio e distinto (o do Velho Oeste continua "convert"); civilização fora da lista cai no padrão; na partida
## a conversão do jogador toca o som da civilização dele e a de outro dono continua muda.
## Uso: godot_console --headless --path . -s res://tools/smoke_convert_sound.gd

var _match: Node
var _bus: Node
var _time := 0.0


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
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)


func _run() -> void:
	await _bus.match_started
	var audio: Node = _match.get_node("Audio")
	var director: Script = load("res://scripts/audio/audio_director.gd")

	# 1. Nomes: um por civilização, todos existem e são distintos; fora da lista = padrão
	var names := []
	for civ in range(1, CivilizationCatalog.count() + 1):
		var sound: String = director.convert_sound(civ)
		_check(director.SOUNDS.has(sound), "civilização %d: o som '%s' não existe" % [civ, sound])
		_check(not names.has(sound), "civilização %d repete o som '%s'" % [civ, sound])
		for other in names:
			_check(director.SOUNDS[sound] != director.SOUNDS[other], "'%s' e '%s' têm as mesmas notas" % [sound, other])
		names.append(sound)
	_check(director.convert_sound(1) == "convert", "o Velho Oeste mantém o som 'convert'")
	_check(director.convert_sound(0) == "convert" and director.convert_sound(99) == "convert", "fora da lista cai no padrão")

	# 2. Na partida: o jogador toca o timbre da civilização dele; outro dono não toca nada
	for civ in range(1, CivilizationCatalog.count() + 1):
		audio.civilization = civ
		audio.played.clear()
		_bus.territory_cells_converted.emit(1, 0.05)
		_check(audio.played == [names[civ - 1]], "civilização %d: tocou %s, esperado %s" % [civ, audio.played, names[civ - 1]])
		await create_timer(0.1).timeout   # passa o intervalo anti-empilhamento
	audio.played.clear()
	_bus.territory_cells_converted.emit(2, 0.05)
	_check(audio.played.is_empty(), "conversão de outro dono não deveria tocar: %s" % [audio.played])
	print("OK")
	quit(0)
