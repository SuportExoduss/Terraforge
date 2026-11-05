class_name TrailCutSensor
extends Node
## Detecta quando este corredor encosta no rastro de OUTRA civilização e ordena o corte (DD-099).
## O invasor não é afetado: segue correndo. Nó filho de um PlanetRunner (precisa do irmão "Civilization").

# Raio de toque: cobre a distância vertical entre o centro do corpo (1 acima do chão) e a linha do rastro.
@export var cut_radius := 1.5
# Carência: rastros recém-nascidos (poucos pontos) ainda não podem ser cortados; evita a cascata de
# cortes no segundo em que alguém sai da própria base.
@export var min_points_to_cut := 5
# A 12 u/s, 12 verificações por segundo dão precisão de corte abaixo de 1 unidade.
@export var check_interval := 0.08

var _runner: PlanetRunner
var _civilization: Civilization
var _clock := 0.0


func _ready() -> void:
	_runner = get_parent() as PlanetRunner
	_civilization = get_parent().get_node_or_null("Civilization") as Civilization
	if _runner == null or _civilization == null:
		push_error("[TrailCutSensor] %s precisa estar sob um PlanetRunner com crachá Civilization." % name)
		set_process(false)


func _process(delta: float) -> void:
	if not _runner.is_active_in_field():   # fantasmas não cortam: pré-GO, embarcado, eliminado, em recall
		return
	_clock += delta
	if _clock < check_interval:
		return
	_clock = 0.0
	var position := _runner.global_position
	# Cópia: um corte pode eliminar o dono do rastro, e ele sai da lista no meio da varredura.
	for trail in Services.trails.duplicate():
		if trail.owner_id != _civilization.id and trail.points.size() >= min_points_to_cut \
				and _is_touching(trail.points, position):
			trail.cut(_civilization.id)


func _is_touching(points: Array, position: Vector3) -> bool:
	var radius_squared := cut_radius * cut_radius
	for i in points.size() - 1:
		var closest := Geometry3D.get_closest_point_to_segment(position, points[i], points[i + 1])
		if closest.distance_squared_to(position) <= radius_squared:
			return true
	return false
