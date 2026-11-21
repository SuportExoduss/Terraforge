class_name AudioDirector
extends Node
## Módulo AUDIO (cap. 05): toca os efeitos da partida escutando só o EventBus (o Gameplay nunca chama o áudio).
## Os sons são SINTETIZADOS aqui (tons com glissando + ruído, PCM 16 bits) — nenhum arquivo de áudio é necessário.
## Só reage ao jogador local; avisos de evento global tocam para todos. Barramentos: Master > SFX e Master > Música.
## ponytail: sons de "sala de máquinas" (ondas simples); trocar por gravações = trocar `_stream()` por `load()`.

const RATE := 22050
const VOICES := 8
const BEAT_SECONDS := 0.9   # Passo 76: com 1..4 pontos de vida (Health.LOW_LIFE_POINTS) o batimento toca a cada 0,9 s
const MIN_GAP_MSEC := 80  # o mesmo som não empilha (um circuito grande dispara vários sinais seguidos)
const SFX_BUS := "SFX"
const MUSIC_BUS := "Música"

# nome -> lista de notas [freq_inicial, freq_final, segundos, volume, mistura_de_ruído 0..1]
const SOUNDS := {
	"capture": [[392, 392, 0.07, 0.5, 0.0], [494, 494, 0.07, 0.5, 0.0], [587, 587, 0.07, 0.5, 0.0], [784, 784, 0.18, 0.55, 0.0]],
	"convert": [[220, 440, 0.20, 0.5, 0.1]],   # Passo 75 (SYS-002 "sons exclusivos"): 1 = Velho Oeste; 2..6 = as demais, na ordem do catálogo
	"convert_2": [[900, 300, 0.12, 0.45, 0.0], [300, 900, 0.12, 0.45, 0.0]],      # Alien: gorjeio
	"convert_3": [[523, 523, 0.07, 0.4, 0.0], [659, 659, 0.13, 0.45, 0.0]],       # Floresta: sininho
	"convert_4": [[300, 700, 0.14, 0.5, 0.3]],                                    # Skate City: roda com ruído
	"convert_5": [[110, 165, 0.12, 0.6, 0.15], [165, 147, 0.14, 0.6, 0.1]],       # Piratas: grave de madeira
	"convert_6": [[2093, 1760, 0.08, 0.4, 0.0], [1760, 1568, 0.14, 0.4, 0.0]],    # Reino do Gelo: vidro
	"cut": [[600, 120, 0.22, 0.6, 0.35]],
	"damage": [[160, 60, 0.25, 0.7, 0.3]],
	"heartbeat": [[75, 50, 0.09, 0.8, 0.0], [50, 50, 0.07, 0.0, 0.0], [65, 45, 0.1, 0.7, 0.0]],   # Passo 76: "tum-tum" grave de pouca vida
	"bonus": [[880, 880, 0.06, 0.45, 0.0], [1175, 1175, 0.06, 0.45, 0.0], [1568, 1568, 0.16, 0.5, 0.0]],
	"sprint": [[300, 1300, 0.16, 0.5, 0.45]],   # Passo 152: "fiu" de corrida (tom subindo com ruído)
	"ability": [[523, 784, 0.07, 0.45, 0.1], [784, 1175, 0.07, 0.45, 0.1], [1175, 1568, 0.16, 0.5, 0.15]],   # arpejo que sobe e "abre"
	"tame": [[330, 330, 0.08, 0.5, 0.0], [415, 415, 0.08, 0.5, 0.0], [494, 494, 0.08, 0.5, 0.0], [659, 659, 0.2, 0.55, 0.0]],   # defensor capturado: fanfarra grave
	"warning": [[660, 660, 0.12, 0.5, 0.0], [440, 440, 0.14, 0.5, 0.0]],
	"tick": [[800, 800, 0.06, 0.4, 0.0]],
	"go": [[1200, 1200, 0.25, 0.5, 0.0]],
	"eliminated": [[300, 80, 0.6, 0.7, 0.2]],
	"end": [[523, 523, 0.15, 0.5, 0.0], [659, 659, 0.15, 0.5, 0.0], [784, 784, 0.15, 0.5, 0.0], [1047, 1047, 0.38, 0.55, 0.0]],
}

var played: Array[String] = []   # últimos sons tocados (o smoke confere por aqui)
var civilization := 1            # Passo 75: civilização do jogador (timbre da conversão)

var _streams: Dictionary = {}    # nome -> AudioStreamWAV (gerado na primeira vez)
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_msec: Dictionary = {}
var _health: int = -1
var _beat_clock := 0.0


func _ready() -> void:
	ensure_buses()
	civilization = CivilizationCatalog.chosen()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	EventBus.territory_loop_claimed.connect(func(id, cells): if id == Civilization.PLAYER_ID and cells >= MatchStats.MIN_LOOP_CELLS: play("capture"))
	EventBus.territory_cells_converted.connect(func(id, _f): if id == Civilization.PLAYER_ID: play(convert_sound(civilization)))
	EventBus.trail_cut.connect(func(_victim, attacker): if attacker == Civilization.PLAYER_ID: play("cut"))
	EventBus.bonus_activated.connect(func(id, _k, _s): if id == Civilization.PLAYER_ID: play("bonus"))
	EventBus.sprint_used.connect(func(id, _c): if id == Civilization.PLAYER_ID: play("sprint"))
	EventBus.ability_used.connect(func(id, _k): if id == Civilization.PLAYER_ID: play("ability"))
	EventBus.defender_captured.connect(func(conqueror, _v): if conqueror == Civilization.PLAYER_ID: play("tame"))
	EventBus.global_event_warning.connect(func(_n, _s): play("warning"))
	EventBus.respawn_countdown.connect(_on_countdown)
	EventBus.health_changed.connect(_on_health)
	EventBus.civilization_eliminated.connect(func(id): if id == Civilization.PLAYER_ID: play("eliminated"))
	EventBus.match_ended.connect(func(): play("end"))


func _process(delta: float) -> void:
	if _health < 1 or _health > Health.LOW_LIFE_POINTS:
		_beat_clock = 0.0   # ao entrar em risco o primeiro batimento é imediato
		return
	_beat_clock -= delta
	if _beat_clock <= 0.0:
		_beat_clock = BEAT_SECONDS
		play("heartbeat")


## Cria os barramentos SFX e Música (filhos do Master) se ainda não existirem.
static func ensure_buses() -> void:
	for bus_name in [SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


## Nome do som de conversão da civilização `civ` (1..6); fora disso, o padrão (Velho Oeste).
static func convert_sound(civ: int) -> String:
	return "convert_%d" % civ if SOUNDS.has("convert_%d" % civ) else "convert"


## Volume de um barramento em escala linear (0 = mudo, 1 = cheio).
static func set_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))
		AudioServer.set_bus_mute(index, linear <= 0.001)


func play(sound: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_msec.get(sound, -MIN_GAP_MSEC)) < MIN_GAP_MSEC:
		return
	_last_msec[sound] = now
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES   # se todas estão ocupadas, a mais antiga é cortada
	voice.stream = stream(sound)
	voice.play()
	played.append(sound)
	if played.size() > 200:
		played.pop_front()


func stream(sound: String) -> AudioStreamWAV:
	if not _streams.has(sound):
		_streams[sound] = SoundBank.stream("sfx:" + sound)   # pré-gerado pelo menu (SoundBank.warm); senão sintetiza aqui
	return _streams[sound]


## Notas em sequência -> AudioStreamWAV mono de 16 bits. Envelope: ataque de 5 ms e queda quadrática.
static func synthesize(notes: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	for note in notes:
		var count := int(note[2] * RATE)
		var bytes_from := data.size()
		data.resize(bytes_from + count * 2)
		for i in count:
			var t := float(i) / count
			phase += TAU * lerpf(note[0], note[1], t) / RATE
			var tone := sin(phase)
			var sample: float = lerpf(tone, randf_range(-1.0, 1.0), note[4])
			var envelope := minf(1.0, i / (RATE * 0.005)) * (1.0 - t) * (1.0 - t)
			data.encode_s16(bytes_from + i * 2, int(clampf(sample * envelope * note[3], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _on_countdown(owner_id: int, seconds_remaining: int) -> void:
	if owner_id == Civilization.PLAYER_ID:
		play("tick" if seconds_remaining > 0 else "go")


func _on_health(owner_id: int, points: int, _max_points: int) -> void:
	if owner_id != Civilization.PLAYER_ID:
		return
	if _health != -1 and points < _health:
		play("damage")
	_health = points
