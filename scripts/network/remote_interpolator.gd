class_name RemoteInterpolator
extends RefCounted
## Jogadores remotos suaves (cap. 04 parte 03, DD-045/046): em vez de pular de snapshot em snapshot (20 por segundo), o
## cliente desenha o OUTRO corredor um pouco no passado (DELAY), entre os dois snapshots que cercam esse instante.
## Sem snapshot mais novo ele para onde está (nunca inventa o futuro); salto grande (o servidor levou o corredor de
## volta à base...) não é interpolado: teletransporta, que é o que de fato aconteceu. O corredor do PRÓPRIO jogador não
## passa por aqui: ele é previsto (RunnerPredictor).
## ponytail: sem extrapolação; se a rede engasgar por mais que DELAY o corredor remoto para e depois retoma.

const DELAY := 0.1          # s: dois snapshots a 20 Hz
const MAX_SAMPLES := 8      # por jogador
const SNAP_DISTANCE := 8.0  # igual ao do RunnerPredictor

var _planet: Object
var _buffers: Dictionary = {}   # civ_id -> Array de {t, pos, fwd}, do mais antigo ao mais novo


func _init(planet: Object) -> void:
	_planet = planet


## Guarda o que o servidor disse sobre o corredor `id` no instante local `time`. Fora de ordem ou repetido é ignorado.
func push(id: int, time: float, pos: Vector3, fwd: Vector3) -> void:
	var buf: Array = _buffers.get_or_add(id, [])
	if not buf.is_empty():
		if time <= buf[-1].t:
			return
		if (buf[-1].pos as Vector3).distance_to(pos) > SNAP_DISTANCE:
			buf.clear()   # salto de verdade: recomeça dali
	buf.append({"t": time, "pos": pos, "fwd": fwd})
	if buf.size() > MAX_SAMPLES:
		buf.pop_front()


func clear() -> void:
	_buffers.clear()


## A pose a desenhar em `now` ({pos, fwd}), ou {} se nunca chegou nada desse corredor.
func sample(id: int, now: float) -> Dictionary:
	var buf: Array = _buffers.get(id, [])
	if buf.is_empty():
		return {}
	var t := now - DELAY
	if t <= buf[0].t:
		return {"pos": buf[0].pos, "fwd": buf[0].fwd}
	for i in range(1, buf.size()):
		if t <= buf[i].t:
			var a: Dictionary = buf[i - 1]
			var b: Dictionary = buf[i]
			var weight: float = (t - a.t) / (b.t - a.t)
			var center: Vector3 = _planet.center   # no planeta a trajetória é um arco, não uma reta
			return {"pos": center + (a.pos - center).slerp(b.pos - center, weight), "fwd": (a.fwd as Vector3).slerp(b.fwd, weight)}
	return {"pos": buf[-1].pos, "fwd": buf[-1].fwd}
