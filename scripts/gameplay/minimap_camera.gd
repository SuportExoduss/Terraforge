class_name MinimapCamera
extends Camera3D
## Câmera-satélite do minimapa (DD-104). Modo BÚSSOLA (padrão): paira sobre o jogador, que fica no centro
## do mini-planeta com a frente para o topo — o mundo gira sob ele. Modo OBSERVATÓRIO (minimapa aberto):
## órbita livre, o arrasto gira o planeta. Filha de um SubViewport: ela só decide ONDE olhar e QUANDO
## redesenhar (15 quadros/s fechado, 30 aberto) — a segunda renderização da cena é o custo do minimapa.

@export var target_path: NodePath
@export_range(0.5, 1.0) var planet_fill_factor: float = 0.95
@export var drag_degrees_per_pixel: float = 0.4
@export var normal_refresh_rate: float = 15.0
@export var expanded_refresh_rate: float = 30.0

var _target: Node3D
var _viewport: SubViewport
var _expanded := false
var _pending_drag := Vector2.ZERO
var _orbit_direction := Vector3.BACK
var _next_render_msec := 0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_viewport = get_parent() as SubViewport
	process_priority = 100   # depois do corredor, como a câmera principal
	EventBus.minimap_held.connect(func(is_held: bool): _expanded = is_held)
	EventBus.minimap_dragged.connect(func(delta_pixels: Vector2): _pending_drag += delta_pixels)


func _process(_delta: float) -> void:
	var planet := Services.planet
	if planet == null:
		return
	# Enquadramento automático: o planeta preenche o quadro.
	var distance := planet.radius / sin(deg_to_rad(fov * 0.5) * planet_fill_factor)

	if not _expanded:
		if _target == null:
			return
		var direction := (_target.global_position - planet.center).normalized()
		global_position = planet.center + direction * distance
		global_basis = Basis.looking_at(-direction, _target.global_basis.z)   # frente do corredor = topo
		_orbit_direction = direction
	else:
		# Sinais: arrastar para a direita leva o planeta para a direita (a câmera vai para a esquerda).
		var yaw := -_pending_drag.x * deg_to_rad(drag_degrees_per_pixel)
		var pitch := -_pending_drag.y * deg_to_rad(drag_degrees_per_pixel)
		_orbit_direction = _orbit_direction.rotated(global_basis.y, yaw).rotated(global_basis.x, pitch).normalized()
		global_position = planet.center + _orbit_direction * distance
		global_basis = Basis.looking_at(-_orbit_direction, global_basis.y)
	_pending_drag = Vector2.ZERO

	if _viewport != null and Time.get_ticks_msec() >= _next_render_msec:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_next_render_msec = Time.get_ticks_msec() + int(1000.0 / (expanded_refresh_rate if _expanded else normal_refresh_rate))
