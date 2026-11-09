extends SceneTree
## Teste de fumaça do Passo 30 (música e ambiente, BD-007/CL-007): (1) os loops sintetizados fecham em laço, a base e a
## camada de tensão têm o MESMO tamanho (ficam em compasso) e não são silêncio; (2) a música entra no começo da partida;
## (3) a tensão sobe com evento global ou nos últimos 60 s e desce depois (fade); (4) o ambiente segue o líder do
## planeta, com histerese; (5) no fim da partida tudo some. Uso: godot_console --headless --path . -s res://tools/smoke_music.gd

const LOOP_FORWARD := 1   # AudioStreamWAV.LoopMode

var _match: Node
var _bus: Node
var _music: Node
var _director: Script
var _failed := false


func _initialize() -> void:
	_director = load("res://scripts/audio/music_director.gd")
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_music = _match.get_node("Music")
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _peak(wav: AudioStreamWAV) -> int:
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = maxi(peak, absi(wav.data.decode_s16(i)))
	return peak


func _db(player_name: String) -> float:
	return _music.get(player_name).volume_db


func _run() -> void:
	# 1. Síntese
	var base: AudioStreamWAV = _director.music_stream(false)
	var tense: AudioStreamWAV = _director.music_stream(true)
	var bed: AudioStreamWAV = _director.ambient_stream(2)
	for pair in [["base", base], ["tensão", tense], ["ambiente", bed]]:
		var wav: AudioStreamWAV = pair[1]
		_check(wav.loop_mode == LOOP_FORWARD, "%s deve tocar em laço" % pair[0])
		_check(wav.loop_end * 2 == wav.data.size(), "%s: o laço deve cobrir o som todo" % pair[0])
		_check(_peak(wav) > 20000, "%s está quase mudo (pico %d)" % [pair[0], _peak(wav)])
	_check(base.data.size() == tense.data.size(), "base e tensão precisam ter o mesmo tamanho (%d x %d)" % [base.data.size(), tense.data.size()])
	var seconds: float = base.data.size() / 2.0 / _director.RATE
	_check(absf(seconds - 10.0) < 0.1, "o loop de música deve ter ~10 s (%.2f)" % seconds)

	# 2. A música entra quando a partida começa
	_check(not _music.playing, "antes do GO a música não toca")
	await _bus.match_started
	await create_timer(1.7).timeout
	_check(_music.playing, "a música deve tocar depois do GO")
	_check(_db("_base") > -20.0, "a camada base deve ter subido (%.1f dB)" % _db("_base"))
	_check(_db("_tense") < -30.0, "a tensão começa em silêncio (%.1f dB)" % _db("_tense"))
	_check(not _music.tension, "sem evento e com relógio cheio não há tensão")

	# 3. Tensão: evento global em execução...
	_bus.global_event_active_changed.emit(true)
	_check(_music.tension, "evento ativo = tensão")
	await create_timer(1.7).timeout
	_check(_db("_tense") > -20.0, "a camada de tensão deve ter subido (%.1f dB)" % _db("_tense"))
	_bus.global_event_active_changed.emit(false)
	_check(not _music.tension, "evento acabou = sem tensão")
	await create_timer(1.7).timeout
	_check(_db("_tense") < -30.0, "a camada de tensão deve ter descido (%.1f dB)" % _db("_tense"))
	# ...e os últimos 60 s
	_bus.match_clock_changed.emit(59)
	_check(_music.tension, "faltando 59 s = tensão")
	_bus.match_clock_changed.emit(61)
	_check(not _music.tension, "faltando 61 s = sem tensão")

	# 4. Ambiente: segue o líder, com histerese de 1 ponto
	_check(_music.ambient_owner == 1, "o ambiente começa na civilização do jogador (%d)" % _music.ambient_owner)
	_bus.territory_score_changed.emit(3, 0.20)
	_check(_music.ambient_owner == 3, "a civ 3 lidera: o ambiente troca (%d)" % _music.ambient_owner)
	_bus.territory_score_changed.emit(2, 0.205)
	_check(_music.ambient_owner == 3, "0,5 ponto à frente não basta (histerese): %d" % _music.ambient_owner)
	_bus.territory_score_changed.emit(2, 0.25)
	_check(_music.ambient_owner == 2, "a civ 2 passou com folga: o ambiente troca (%d)" % _music.ambient_owner)
	await create_timer(1.7).timeout
	var beds: Array = _music.get("_beds")
	var active: int = _music.get("_bed")
	_check(beds[active].volume_db > -30.0 and beds[1 - active].volume_db < -30.0, "crossfade: só a cama nova fica audível (%.1f / %.1f)" % [beds[active].volume_db, beds[1 - active].volume_db])

	# 5. Fim da partida
	_bus.match_ended.emit()
	_check(not _music.playing, "no fim da partida a música para")
	await create_timer(1.7).timeout
	_check(_db("_base") < -30.0 and beds[0].volume_db < -30.0 and beds[1].volume_db < -30.0, "tudo deve ter silenciado")

	if not _failed:
		print("OK")
		quit(0)
