class_name ContemplationCamera
extends Node
## Câmera de contemplação (GDMD: "o planeta permanece disponível para contemplação"): dorme durante a
## partida e desperta no fim — ou quando o jogador é eliminado (R1: assiste como espectador). Afasta a
## câmera principal até enquadrar o planeta inteiro e deixa girá-lo arrastando (mouse/toque) ou com
## A/D e setas (W/S inclinam); sem comando, a vitrine gira sozinha. Assume a câmera que o RunnerCamera
## larga ao fim da partida.

@export var camera_path: NodePath
## Distância final = raio x fator. No retrato o FOV horizontal é o estreito: 3,5 deixa folga nas bordas.
@export var distance_factor: float = 3.5
@export var approach_smoothing: float = 1.5
@export var drag_degrees_per_pixel: float = 0.2
@export var key_orbit_speed_degrees: float = 60.0
@export var auto_orbit_speed_degrees: float = 10.0

var _camera: Camera3D
var _active := false
var _drag := Vector2.ZERO


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	EventBus.match_ended.connect(func(): _active = true)
	EventBus.civilization_eliminated.connect(func(owner_id: int): _active = _active or owner_id == Civilization.PLAYER_ID)


func _unhandled_input(event: InputEvent) -> void:
	if _active and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag += event.relative


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
	if orbit == Vector2.ZERO:
		orbit.x = deg_to_rad(auto_orbit_speed_degrees) * delta   # vitrine

	var offset := _camera.global_position - planet.center
	offset = offset.rotated(_camera.global_basis.y, orbit.x).rotated(_camera.global_basis.x, orbit.y)

	# Afastamento suave até a distância de contemplação (exponencial: independe da taxa de quadros).
	var step := 1.0 - exp(-approach_smoothing * delta)
	var distance := lerpf(offset.length(), planet.radius * distance_factor, step)
	offset = offset.normalized() * distance

	_camera.global_position = planet.center + offset
	_camera.global_basis = Basis.looking_at(-offset.normalized(), _camera.global_basis.y)
