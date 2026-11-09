class_name RunnerPredictor
extends RefCounted
## Predição do corredor do próprio jogador no cliente (cap. 04 parte 03, DD-044..046). A direção responde NA HORA:
## o cliente roda o mesmo passo do servidor (RunnerMotion) e guarda os comandos ainda não confirmados. Quando chega
## um snapshot, parte do estado OFICIAL, reaplica os comandos pendentes (> ack) e a diferença para o que já estava
## na tela vira um deslocamento visual que se dissolve suave: nunca teletransporta sem necessidade.
## Só o servidor decide: o cliente jamais cria território, tira vida ou define resultado.

const TOLERANCE := 0.05          # abaixo disso a diferença nem é corrigida (sem tremedeira)
const LARGE_ERROR := 0.5         # acima disso a reconciliação é mais rápida (mas ainda suave)
const SNAP_DISTANCE := 8.0       # só acima disso há teletransporte (o servidor mandou o corredor longe: volta à base...)
const SMALL_RATE := 4.0          # velocidade (1/s) de dissolver correções pequenas
const LARGE_RATE := 10.0         # idem, grandes
const MAX_BLIND_SECONDS := 1.5   # sem snapshot por mais que isso, a predição congela em vez de inventar o futuro

var speed := 12.0                # iguais aos de PlanetRunner; bônus/lentidão são do servidor e voltam pela reconciliação
var turn_degrees := 180.0
var height_offset := 1.0
var latency := 0.0               # segundos; latência alta alarga a tolerância: menos correções visíveis

var position := Vector3.ZERO     # estado previsto (sem a suavização visual)
var forward := Vector3.FORWARD
var pending: Array = []   # comandos enviados e ainda não confirmados: {seq, steer, dt}

var _planet: Object
var _pos_offset := Vector3.ZERO
var _yaw_offset := 0.0
var _blind := 0.0
var _ready_state := false


func _init(planet: Object) -> void:
	_planet = planet


func is_ready() -> bool:
	return _ready_state


func is_frozen() -> bool:
	return _blind > MAX_BLIND_SECONDS


## Começa do estado oficial (primeiro snapshot, ou depois de uma reconexão: estado completo).
func reset(server_position: Vector3, server_forward: Vector3) -> void:
	position = server_position
	forward = server_forward
	pending.clear()
	_pos_offset = Vector3.ZERO
	_yaw_offset = 0.0
	_blind = 0.0
	_ready_state = true


## Prevê um quadro com o comando `seq` (o mesmo que foi para o servidor).
func predict(seq: int, steer: float, dt: float) -> void:
	if not _ready_state or is_frozen():
		return
	_step(steer, dt)
	pending.append({"seq": seq, "steer": steer, "dt": dt})


## Chegou o estado oficial: refaz a partir dele o que o servidor ainda não viu e dissolve a diferença.
func reconcile(server_position: Vector3, server_forward: Vector3, ack: int) -> void:
	if not _ready_state:
		reset(server_position, server_forward)
		return
	_blind = 0.0
	var shown_position := visual_position()
	var shown_forward := visual_forward()
	pending = pending.filter(func(cmd: Dictionary) -> bool: return cmd.seq > ack)
	position = server_position
	forward = server_forward
	for cmd in pending:
		_step(cmd.steer, cmd.dt)
	var error := shown_position - position
	if error.length() > SNAP_DISTANCE:
		_pos_offset = Vector3.ZERO   # necessidade real: o servidor levou o corredor para longe
		_yaw_offset = 0.0
		return
	var up: Vector3 = (position - _planet.center).normalized()
	_pos_offset = error if error.length() >= _tolerance() or _pos_offset != Vector3.ZERO else Vector3.ZERO
	_yaw_offset = forward.signed_angle_to(shown_forward, up)


## A cada quadro de tela: dissolve o deslocamento visual e conta o tempo sem notícias do servidor.
func update_visual(dt: float) -> void:
	_blind += dt
	var rate := LARGE_RATE if _pos_offset.length() > LARGE_ERROR else SMALL_RATE
	var keep := exp(-rate * dt)
	_pos_offset *= keep
	_yaw_offset *= keep
	if _pos_offset.length() < 0.001:
		_pos_offset = Vector3.ZERO


func visual_position() -> Vector3:
	return position + _pos_offset


func visual_forward() -> Vector3:
	var up: Vector3 = (position - _planet.center).normalized()
	return forward.rotated(up, _yaw_offset)


func _tolerance() -> float:
	return TOLERANCE + latency * speed * 0.25


func _step(steer: float, dt: float) -> void:
	var moved := RunnerMotion.advance(position, forward, steer, dt, _planet, height_offset, speed, turn_degrees)
	position = moved[0]
	forward = moved[1]
