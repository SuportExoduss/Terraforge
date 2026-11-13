extends SceneTree
## Teste de fumaça do Passo 90 (desempenho): SoundBank sintetiza música, efeitos e camas de ambiente numa thread (warm) e entrega prontos.
## Antes: a música levava ~450 ms do _ready da partida e cada efeito 6–24 ms no 1º uso (no meio da corrida).
## Uso: godot_console --headless --path . -s res://tools/smoke_sound_bank.gd

func _initialize() -> void:
	var bad: Array[String] = []
	# load() em tempo de execução: o SoundBank cita AudioDirector/MusicDirector, que citam o autoload EventBus (ausente na compilação de um -s)
	var bank = load("res://scripts/audio/sound_bank.gd")
	var director = load("res://scripts/audio/audio_director.gd")
	var t := Time.get_ticks_usec()
	bank.warm()
	var warm_ms := (Time.get_ticks_usec() - t) / 1000.0
	if warm_ms > 15.0:
		bad.append("warm() bloqueou %.1f ms (devia só disparar a thread)" % warm_ms)
	var keys: Array = bank.keys()
	if keys.size() != 2 + director.SOUNDS.size() + 6:
		bad.append("%d chaves (esperava música 2 + efeitos %d + ambiente 6)" % [keys.size(), director.SOUNDS.size()])
	var first := {}
	for key in keys:
		var wav: AudioStreamWAV = bank.stream(key)
		if wav == null or wav.data.is_empty():
			bad.append("%s vazio" % key)
		first[key] = wav
	t = Time.get_ticks_usec()
	for key in keys:
		if bank.stream(key) != first[key]:
			bad.append("%s: o 2º stream() devolveu outro objeto" % key)
	var again_ms := (Time.get_ticks_usec() - t) / 1000.0
	if again_ms > 5.0:
		bad.append("%d leituras prontas levaram %.1f ms (esperado < 5)" % [keys.size(), again_ms])
	var direct: AudioStreamWAV = director.synthesize(director.SOUNDS["capture"])
	if direct.data.size() != first["sfx:capture"].data.size():
		bad.append("sfx:capture difere da síntese direta")
	for b in bad:
		print("FALHOU: ", b)
	print("OK" if bad.is_empty() else "FALHOU", " (warm %.1f ms · %d sons)" % [warm_ms, keys.size()])
	quit(0 if bad.is_empty() else 1)
