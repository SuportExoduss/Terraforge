class_name ContemplationCamera
extends Node
## Câmera de contemplação (GDMD: "o planeta permanece disponível para contemplação"): dorme durante a
## partida e desperta no fim — ou quando o jogador é eliminado (R1: assiste como espectador). Afasta a
## câmera principal até enquadrar o planeta inteiro e deixa girá-lo arrastando (mouse/toque) ou com
## A/D e setas (W/S inclinam); sem comando, a vitrine gira sozinha. Assume a câmera que o RunnerCamera
## larga ao fim da partida. Passo 64: roda do mouse e +/- aproximam/afastam (com limites); sem pinça no toque (ponytail).
## Passo 65: TAB gira a câmera até a base da próxima civilização ("observar cada civilização"); girar à mão cancela.

@export var camera_path: NodePath
## Distância final = raio x fator. No retrato o FOV horizontal é o estreito: 3,5 deixa folga nas bordas.
@export var distance_factor: float = 3.5
@export var approach_smoothing: float = 1.5
@export var drag_degrees_per_pixel: float = 0.2
@export var key_orbit_speed_degrees: float = 60.0
@export var auto_orbit_speed_degrees: float = 10.0
@export var min_factor: float = 1.8   # mais perto que isso a câmera entraria nas montanhas
@export var max_factor: float = 6.0
@export var zoom_step: float = 1.15   # por clique da roda / por toque de tecla
@export var focus_smoothing: float = 4.0

var _camera: Camera3D
var _active := false
var _drag := Vector2.ZERO
var _focus_dir := Vector3.ZERO   # direção (do centro) da base observada; zero = sem foco
var _observed_id := 0            # civilização observada por último (TAB passa à próxima id)
var _factor: float   # distância alvo = raio x _factor; o zoom mexe aqui (começa em distance_factor)


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_factor = distance_factor
	EventBus.match_ended.connect(func(): _active = true)
	EventBus.civilization_eliminated.connect(func(owner_id: int): _active = _active or owner_id == Civilization.PLAYER_ID)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag += event.relative
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.0 / zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB and not event.echo:
			_observe_next()
		elif event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			_zoom(1.0 / zoom_step)
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom(zoom_step)


## Passo 65: a próxima id (em ordem, dando a volta) que ainda tem base; sem base nenhuma, não faz nada.
func _observe_next() -> void:
	var ids: Array = Services.home_bases.keys()
	if ids.is_empty():
		return
	ids.sort()
	var later: Array = ids.filter(func(id: int) -> bool: return id > _observed_id)
	_observed_id = later.front() if not later.is_empty() else ids.front()
	_focus_dir = (Services.home_bases[_observed_id]["position"] - Services.planet.center).normalized()


func _zoom(multiplier: float) -> void:
	_factor = clampf(_factor * multiplier, min_factor, max_factor)


func _process(delta: float) -> void:
	var planet := Services.planet
	if not _active or _camera == null or planet == null:
		_drag = Vector2.ZERO
		return

	# Positivo = a câmera vai para a direita / para baixo (mesmos sinais do minimapa): arrastar para a
	# direita leva o planeta para a direita, logo a câmera vai para a esquerda.
	var orbit := Vector2(-_drag.x, -_drag.y) * deg_to_rad(drag_degrees_per_pixel)
	_drag = Vector2.ZERO
	var key_step := deg_to_rad(key_orbit_speed_degrees) * delta
	var keys := Vector2(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	orbit += keys * key_step
	if orbit != Vector2.ZERO:
		_focus_dir = Vector3.ZERO   # o jogador pegou o comando
	elif _focus_dir == Vector3.ZERO:
		orbit.x = deg_to_rad(auto_orbit_speed_degrees) * delta   # vitrine

	var offset := _camera.global_position - planet.center
	var up := _camera.global_basis.y
	offset = offset.rotated(up, orbit.x).rotated(_camera.global_basis.x, orbit.y)
	if _focus_dir != Vector3.ZERO:
		var angle := offset.angle_to(_focus_dir)
		if angle < 0.01:
			_focus_dir = Vector3.ZERO   # chegou: a vitrine volta a girar
		else:
			var axis := offset.cross(_focus_dir)
			axis = axis.normalized() if axis.length() > 0.0001 else up   # do lado oposto: gira por cima
			var turn := angle * (1.0 - exp(-focus_smoothing * delta))
			offset = offset.rotated(axis, turn)
			up = up.rotated(axis, turn)

	# Afastamento suave até a distância de contemplação (exponencial: independe da taxa de quadros).
	var step := 1.0 - exp(-approach_smoothing * delta)
	var distance := lerpf(offset.length(), planet.radius * _factor, step)
	offset = offset.normalized() * distance

	_camera.global_position = planet.center + offset
	_camera.global_basis = Basis.looking_at(-offset.normalized(), up)
