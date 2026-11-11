class_name EarthquakeEvent
extends GlobalEvent
## SYS-004 / DD-107: o TERREMOTO. AVISO: rachaduras finas riscam o chão (a contagem corre) → EXECUÇÃO: as rachaduras
## abrem e pedras caem (cada uma mostra a sombra crescente de onde vai cair). Ao ENTRAR numa rachadura aberta: 1 pt;
## pedra que cai em cima: 1 pt; PRESO (a rachadura fecha com o corredor dentro): 2 pts (DD-107). As rachaduras fecham
## uma de cada vez → CICATRIZ: rachaduras finas e pedras no chão até "tudo voltar" (DD-108) + cristais (DD-106).
## Nunca mexe no território (DD-024).
## ponytail: rachadura = 3 caixas escuras rasas (acompanham a curva); rachaduras e pedras nascem perto dos corredores
## (senão ninguém é atingido num planeta de raio 100); sem tremor de câmera nem regiões subindo/afundando.

const EVENT_NAME := "TERREMOTO IMINENTE"
const CRACKS := 6
const SEGMENTS := 3         # caixas por rachadura
const ROCKS := 10
const LIVE_OPEN := 0.3      # acima disso a rachadura já machuca
const THIN := 0.35          # largura da rachadura fechada (aviso e cicatriz)
const TOUCH_DAMAGE := 1
const TRAP_DAMAGE := 2
const RUNNER_MARGIN := 0.4
const ROCK_SCALE := Vector3(2.4, 1.8, 2.4)
const ROCK_WAITING := 0
const ROCK_FALLING := 1
const ROCK_LANDED := 2

@export var quake_seconds := 14.0            # mínimo; o fim real espera a última rachadura fechar
@export var open_seconds := 1.0
@export var first_close_seconds := 7.0
@export var close_gap_seconds := 0.8
@export var close_seconds := 1.2
@export var crack_length := 27.0
@export var crack_width := 3.0
@export var crack_spread := 40.0             # u (pelo chão) entre um corredor e suas rachaduras
@export var rock_interval := 1.0
@export var rock_fall_seconds := 1.2
@export var rock_height := 28.0
@export var rock_hit_radius := 2.2
@export var rock_spread := 16.0

var _crack_dir: Array[Vector3] = []
var _crack_axis: Array[Vector3] = []
var _cracks: Array[MeshInstance3D] = []      # CRACKS * SEGMENTS
var _closed: Array[bool] = []
var _inside: Array[Dictionary] = []          # por rachadura: id do corredor -> já levou o dano de entrar
var _rock_dir: Array[Vector3] = []
var _rock_state: Array[int] = []
var _rock_age: Array[float] = []
var _rocks: Array[MeshInstance3D] = []
var _marks: Array[MeshInstance3D] = []
var _next_rock := 0.0
var _rocks_dropped := 0


func _event_name() -> String:
	return EVENT_NAME


func _active_seconds() -> float:
	return maxf(quake_seconds, _close_at(CRACKS - 1) + close_seconds)


func _setup() -> void:
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3.ONE
	crack_mesh.material = _unshaded(Color(0.05, 0.03, 0.02))
	for i in CRACKS:
		for s in SEGMENTS:
			var piece := MeshInstance3D.new()
			piece.name = "Crack%d_%d" % [i, s]
			piece.mesh = crack_mesh
			piece.visible = false
			add_child(piece)
			_cracks.append(piece)
		_crack_dir.append(Vector3.UP)
		_crack_axis.append(Vector3.RIGHT)
		_closed.append(false)
		_inside.append({})
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.5
	rock_mesh.height = 1.0
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 4
	rock_mesh.material = _unshaded(Color(0.42, 0.38, 0.33))
	for i in ROCKS:
		var rock := MeshInstance3D.new()
		rock.name = "Rock%d" % i
		rock.mesh = rock_mesh
		rock.visible = false
		add_child(rock)
		_rocks.append(rock)
		_marks.append(make_disc("Mark%d" % i, Color(0.1, 0.07, 0.05, 1.0)))
		_rock_dir.append(Vector3.UP)
		_rock_state.append(ROCK_WAITING)
		_rock_age.append(0.0)


func _begin_warning() -> bool:
	var cracks := []
	for i in CRACKS:
		cracks.append(spot_near_runner(0.0, crack_spread))
	var rocks := []
	for i in ROCKS:
		rocks.append(spot_near_runner(0.0, rock_spread))
	plan(cracks, rocks)
	print("[World] TERREMOTO iminente! (DD-107)")
	return true


## Fixa o centro de cada rachadura e o ponto de queda de cada pedra (vetores a partir do centro do planeta; o que
## faltar é sorteado no planeta todo). Também usada pelos testes.
func plan(cracks: Array, rocks: Array) -> void:
	_hide()
	for i in CRACKS:
		_crack_dir[i] = (cracks[i] if i < cracks.size() else random_direction()).normalized()
		_crack_axis[i] = ground_basis(_crack_dir[i]).x.rotated(_crack_dir[i], randf() * TAU)
		_closed[i] = false
		_inside[i].clear()
		_place_crack(i, 0.1)
	for i in ROCKS:
		_rock_dir[i] = (rocks[i] if i < rocks.size() else random_direction()).normalized()


func _tick_warning(remaining: float, _delta: float) -> void:
	var progress := clampf(1.0 - remaining / warning_seconds, 0.0, 1.0)
	for i in CRACKS:
		_place_crack(i, lerpf(0.1, THIN, progress))   # as rachaduras vão se riscando


func _begin_active() -> void:
	_next_rock = 0.4
	_rocks_dropped = 0
	for i in CRACKS:
		_closed[i] = false
		_inside[i].clear()


func _tick_active(delta: float) -> bool:
	_next_rock -= delta
	if _next_rock <= 0.0 and _rocks_dropped < ROCKS and clock < _active_seconds() - rock_fall_seconds:
		_next_rock += rock_interval
		_drop_rock()
	_fall_rocks(delta)
	_update_cracks()
	return clock >= _active_seconds()


func _begin_scar() -> void:
	for i in CRACKS:
		_place_crack(i, THIN)
	for mark in _marks:
		mark.visible = false
	EventBus.bonus_drop_requested.emit(ground_point(_crack_dir[0]), randi_range(2, 3))   # as rachaduras mostram cristais
	print("[World] O terremoto passou: rachaduras e pedras (DD-108).")


func _tick_scar(life: float) -> void:
	for i in CRACKS:
		_place_crack(i, THIN * life)
	for i in ROCKS:
		if _rock_state[i] == ROCK_LANDED:
			_rocks[i].scale = ROCK_SCALE * life


func _hide() -> void:
	for node in _cracks + _rocks + _marks:
		node.visible = false
	_rock_state.fill(ROCK_WAITING)


## 0 (fechada) a 1 (aberta) da rachadura `i` agora: abre no começo da execução e fecha na sua vez.
func open_amount(i: int) -> float:
	if state != State.ACTIVE:
		return 0.0
	return minf(clock / open_seconds, 1.0) * clampf(1.0 - (clock - _close_at(i)) / close_seconds, 0.0, 1.0)


## `pos` está dentro do retângulo da rachadura `i` (a largura cheia vale até ela fechar de vez).
func on_crack(i: int, pos: Vector3) -> bool:
	var unit := (pos - Services.planet.center).normalized()
	if unit.dot(_crack_dir[i]) < 0.9:   # sem isto o antípoda cairia no retângulo projetado
		return false
	var d := pos - ground_point(_crack_dir[i])
	var side := _crack_dir[i].cross(_crack_axis[i])
	return absf(d.dot(_crack_axis[i])) <= crack_length * 0.5 and absf(d.dot(side)) <= crack_width * 0.5 + RUNNER_MARGIN


func _close_at(i: int) -> float:
	return first_close_seconds + i * close_gap_seconds


func _update_cracks() -> void:
	var runners := get_tree().get_nodes_in_group("runners")
	for i in CRACKS:
		if _closed[i]:
			continue
		var amount := open_amount(i)
		var finished := clock >= _close_at(i) + close_seconds
		_place_crack(i, lerpf(THIN, crack_width, amount))
		for node in runners:
			var runner := node as PlanetRunner
			var id := runner.get_instance_id()
			if not runner.is_active_in_field() or not on_crack(i, runner.global_position):
				_inside[i].erase(id)
			elif finished:
				_hurt(runner, TRAP_DAMAGE)   # a rachadura fechou com ele dentro
			elif amount > LIVE_OPEN and not _inside[i].has(id):
				_inside[i][id] = true
				_hurt(runner, TOUCH_DAMAGE)
		if finished:
			_closed[i] = true
			_inside[i].clear()


func _drop_rock() -> void:
	var i := _rocks_dropped
	_rocks_dropped += 1
	_rock_state[i] = ROCK_FALLING
	_rock_age[i] = 0.0
	_place_rock(i, rock_height, ROCK_SCALE)


func _fall_rocks(delta: float) -> void:
	for i in ROCKS:
		if _rock_state[i] != ROCK_FALLING:
			continue
		_rock_age[i] += delta
		var t := _rock_age[i] / rock_fall_seconds
		if t < 1.0:
			place_disc(_marks[i], _rock_dir[i], maxf(rock_hit_radius * 2.0 * t, 0.2))   # a sombra cresce
			_place_rock(i, lerpf(rock_height, 0.7, t * t), ROCK_SCALE)
			continue
		_rock_state[i] = ROCK_LANDED
		_marks[i].visible = false
		_place_rock(i, 0.7, ROCK_SCALE)
		var landing := ground_point(_rock_dir[i])
		for node in get_tree().get_nodes_in_group("runners"):
			var runner := node as PlanetRunner
			if runner.is_active_in_field() and runner.global_position.distance_to(landing) <= rock_hit_radius:
				_hurt(runner, TOUCH_DAMAGE)


func _place_rock(i: int, height: float, rock_scale: Vector3) -> void:
	var direction := _rock_dir[i]
	_rocks[i].global_transform = Transform3D(ground_basis(direction).rotated(direction, float(i)), ground_point(direction) + direction * height)
	_rocks[i].scale = rock_scale
	_rocks[i].visible = true


# Rachadura `i` com `width` de largura, em SEGMENTS caixas seguindo a curva do planeta.
func _place_crack(i: int, width: float) -> void:
	var piece := crack_length / SEGMENTS
	for s in SEGMENTS:
		var offset := (s - (SEGMENTS - 1) * 0.5) * piece
		var direction := (_crack_dir[i] + _crack_axis[i] * (offset / Services.planet.radius)).normalized()
		var along := (_crack_axis[i] - direction * _crack_axis[i].dot(direction)).normalized()
		var node := _cracks[i * SEGMENTS + s]
		node.global_transform = Transform3D(Basis(along, direction, along.cross(direction)), ground_point(direction) + direction * 0.1)
		node.scale = Vector3(piece + 0.3, 0.25, maxf(width, 0.02))
		node.visible = true


func _hurt(runner: PlanetRunner, points: int) -> void:
	var health := runner.get_node_or_null("Health") as Health
	if health != null:
		health.take_damage(points, "TERREMOTO")



func _focus_direction() -> Vector3:
	return _crack_dir[0]   # ponytail: o minimapa marca só a 1ª rachadura (as outras ficam perto dela)
