class_name SoundBank
extends RefCounted
## Sons sintetizados em GDScript (efeitos, música, cama de ambiente), guardados prontos. MEDIDO: a música levava ~450 ms do _ready da partida
## e cada efeito 6–24 ms no 1º uso (142 ms no total), no meio da corrida. O menu chama warm(): a síntese roda numa thread enquanto o
## jogador escolhe; stream() pega o pronto (espera o fim da thread se faltar) ou sintetiza na hora se ninguém chamou warm() (servidor, testes).
## ponytail: chave "tipo:nome"; trilha gravada no lugar da sintética = trocar só _make().

static var _streams: Dictionary = {}   # chave -> AudioStreamWAV (só a thread escreve, e só até o stream() esperar por ela)
static var _task := -1


## Chaves de tudo que a partida toca: efeitos, as 2 camadas de música e as camas de ambiente (civilização % 6).
static func keys() -> Array[String]:
	var out: Array[String] = ["music:base", "music:tense"]
	for sound in AudioDirector.SOUNDS:
		out.append("sfx:" + sound)
	for i in 6:
		out.append("ambient:%d" % i)
	return out


static func warm() -> void:
	if _task == -1 and _streams.is_empty():
		_task = WorkerThreadPool.add_task(_build_all, false, "sound_bank")


static func stream(key: String) -> AudioStreamWAV:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)   # termina o que faltar (se warm() já acabou, volta na hora)
		_task = -1
	if not _streams.has(key):
		_streams[key] = _make(key)
	return _streams[key]


static func _build_all() -> void:
	var built := {}
	for key in keys():
		built[key] = _make(key)
	_streams.merge(built)


static func _make(key: String) -> AudioStreamWAV:
	var arg := key.get_slice(":", 1)
	match key.get_slice(":", 0):
		"sfx":
			return AudioDirector.synthesize(AudioDirector.SOUNDS[arg])
		"music":
			return MusicDirector.music_stream(arg == "tense")
		"ambient":
			return MusicDirector.ambient_stream(arg.to_int())
	return null
