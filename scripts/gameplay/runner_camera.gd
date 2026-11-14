class_name RunnerCamera
extends Camera3D
## Câmera superior: paira acima do corredor olhando para baixo, com a frente do personagem para o
## topo da tela. DD-126 (paisagem): mira um ponto À FRENTE do corredor (horizonte no topo).

@export var target_path: NodePath
@export var height: float = 12.0
@export var back_distance: float = 16.0
@export var look_ahead_distance: float = 18.0
@export var position_smoothing: float = 5.0
@export var rotation_smoothing: float = 5.0

var _target: PlanetRunner
var _enabled := true


func _ready() -> void:
	_target = get_node_or_null(target_path) as PlanetRunner
	# Roda DEPOIS do corredor: ele se move primeiro, a câmera reage por último.
	process_priority = 100
	EventBus.match_ended.connect(func(): _enabled = false)
	EventBus.civilization_eliminated.connect(_on_eliminated)


func _on_eliminated(owner_id: int) -> void:
	if owner_id == Civilization.PLAYER_ID:
		_enabled = false


func _process(delta: float) -> void:
	if _target == null or not _enabled or not Services.planet or not Services.planet.surface_ready:
		return
	var up := _target.global_transform.basis.y
	var fwd := _target.global_transform.basis.z
	var desired_pos := _target.global_position + up * height - fwd * back_distance
	var look_point := _target.global_position + fwd * look_ahead_distance
	var desired_basis := Basis.looking_at(look_point - desired_pos, up)

	# Suavização exponencial: independe da taxa de quadros.
	var move_step := 1.0 - exp(-position_smoothing * delta)
	var turn_step := 1.0 - exp(-rotation_smoothing * delta)
	global_position = global_position.lerp(desired_pos, move_step)
	global_transform.basis = global_transform.basis.orthonormalized().slerp(desired_basis, turn_step)
