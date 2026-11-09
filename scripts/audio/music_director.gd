class_name MusicDirector
extends Node
## Música e som ambiente (BD-007, CL-007): tudo SINTETIZADO por código, como os efeitos do AudioDirector.
## - Música: loop de 10 s (4 acordes) em duas camadas sincronizadas — base e "tensão" (pulso + grave).
##   A tensão entra com evento global em execução ou nos últimos 60 s, e sai de volta (fade de 1,5 s).
## - Ambiente: uma cama de ruído filtrado + drone por civilização; toca a da civilização que LIDERA o planeta
##   e faz crossfade quando a liderança muda (histerese de 1 ponto percentual para não ficar trocando).
## Escuta só o EventBus. Tudo sai pelo barramento "Música".
## ponytail: sons de "sala de máquinas" em 11 kHz; trocar por trilha gravada = trocar `music_stream()`.

const RATE := 11025
const BPM := 96.0
const STEPS := 32   # colcheias: 4 acordes x 8
const FADE_SECONDS := 1.5
const QUIET_DB := -40.0
const MUSIC_DB := -14.0
const AMBIENT_DB := -24.0
const TENSION_CLOCK := 60
const LEAD_HYSTERESIS := 0.01
const AMBIENT_SECONDS := 4.0
# Dó menor – Láb – Mib – Sib: [raiz do baixo, 3 notas do arpejo] em Hz
const CHORDS := [[65.41, 130.81, 155.56, 196.00], [51.91, 103.83, 130.81, 155.56], [77.78, 155.56, 196.00, 233.08], [58.27, 116.54, 146.83, 174.61]]
const ARPEGGIO := [1, 2, 3, 2, 3, 2, 1, 2]

var tension := false
var ambient_owner := -1
var playing := false

var _event_active := false
var _late := false
var _fractions: Dictionary = {}
var _base: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _beds: Array[AudioStreamPlayer] = []   # duas camas: uma toca, a outra recebe o crossfade
var _bed := 0
var _tweens: Dictionary = {}


func _ready() -> void:
	AudioDirector.ensure_buses()
	_base = _player(music_stream(false))
	_tense = _player(music_stream(true))
	_beds = [_player(null), _player(null)]
	EventBus.match_started.connect(_start)
	EventBus.match_ended.connect(_stop)
	EventBus.global_event_active_changed.connect(func(active): _event_active = active; _update_tension())
	EventBus.match_clock_changed.connect(func(seconds): _late = seconds <= TENSION_CLOCK; _update_tension())
	EventBus.territory_score_changed.connect(_on_score)


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = AudioDirector.MUSIC_BUS
	player.stream = stream
	player.volume_db = QUIET_DB
	add_child(player)
	return player


func _start() -> void:
	if playing:
		return
	playing = true
	_base.play()   # as duas camadas nascem juntas: o mesmo tamanho de loop as mantém em compasso
	_tense.play()
	_fade(_base, MUSIC_DB)
	_set_ambient(Civilization.PLAYER_ID if ambient_owner == -1 else ambient_owner, true)


func _stop() -> void:
	playing = false
	tension = false
	for player in [_base, _tense, _beds[0], _beds[1]]:
		_fade(player, QUIET_DB)


func _update_tension() -> void:
	var want := _event_active or _late
	if want != tension:
		tension = want
		if playing:
			_fade(_tense, MUSIC_DB if tension else QUIET_DB)


func _on_score(owner_id: int, fraction: float) -> void:
	_fractions[owner_id] = fraction
	var leader := owner_id
	for id in _fractions:
		if _fractions[id] > _fractions[leader]:
			leader = id
	var current: float = _fractions.get(ambient_owner, 0.0)
	if leader != ambient_owner and _fractions[leader] > current + LEAD_HYSTERESIS:
		_set_ambient(leader, false)


func _set_ambient(civilization_id: int, immediate: bool) -> void:
	ambient_owner = civilization_id
	if not playing:
		return   # a cama certa nasce quando a música começar
	var old := _beds[_bed]
	_bed = 1 - _bed
	var bed := _beds[_bed]
	bed.stream = ambient_stream(civilization_id)
	bed.volume_db = AMBIENT_DB if immediate else QUIET_DB
	bed.play()
	if not immediate:
		_fade(bed, AMBIENT_DB)
		_fade(old, QUIET_DB)


func _fade(player: AudioStreamPlayer, db: float) -> void:
	if _tweens.has(player) and _tweens[player].is_valid():
		_tweens[player].kill()
	_tweens[player] = create_tween()
	_tweens[player].tween_property(player, "volume_db", db, FADE_SECONDS)


# --- síntese ---------------------------------------------------------------------------------------------

## Loop de música: a base (baixo + pad + arpejo) ou a camada de tensão (pulso + grave dobrado).
static func music_stream(tense_layer: bool) -> AudioStreamWAV:
	var step := 60.0 / BPM / 2.0
	var buf := PackedFloat32Array()
	buf.resize(int(STEPS * step * RATE))
	for s in STEPS:
		var chord: Array = CHORDS[s / 8]
		var t := s * step
		if tense_layer:
			_add(buf, t, step * 0.4, 0.0, 0.18, true)                      # chimbal de ruído a cada colcheia
			if s % 2 == 0:
				_add(buf, t, step * 1.8, chord[0] * 0.5, 0.45, false)      # grave dobrado
		else:
			if s % 8 == 0:
				_add(buf, t, step * 7.5, chord[1], 0.22, false)            # pad do acorde
				_add(buf, t, step * 2.0, chord[0], 0.5, false)             # baixo
			_add(buf, t, step * 1.6, chord[ARPEGGIO[s % 8]] * 2.0, 0.3, false)
	return _to_wav(buf, true)


## Cama de ambiente de uma civilização: drone + ruído filtrado com ondulação lenta (vento). Fecha em laço exato.
static func ambient_stream(civilization_id: int) -> AudioStreamWAV:
	var count := int(AMBIENT_SECONDS * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var drone := 55.0 + 11.0 * (civilization_id % 6)          # múltiplos de 1/4 Hz: o laço fecha sem estalo
	var coef := 0.03 + 0.03 * (civilization_id % 6)           # quanto maior, mais "brilhante" o vento
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		low += coef * (randf_range(-1.0, 1.0) - low)
		var wave := 0.75 + 0.25 * sin(TAU * 0.5 * t)         # 2 ondulações por laço
		buf[i] = (0.5 * sin(TAU * drone * t) + 4.0 * low) * wave
	return _to_wav(buf, true)


# Soma uma nota (seno + 2º harmônico, ataque 8 ms, queda exponencial) ou um sopro de ruído no buffer.
static func _add(buf: PackedFloat32Array, start: float, seconds: float, freq: float, volume: float, noise: bool) -> void:
	var first := int(start * RATE)
	var count := mini(int(seconds * RATE), buf.size() - first)
	for i in count:
		var t := float(i) / RATE
		var tone := randf_range(-1.0, 1.0) if noise else sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)
		buf[first + i] += tone * volume * minf(1.0, t / 0.008) * exp(-4.0 * t / seconds)


static func _to_wav(buf: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav
