class_name GlobalEvent
extends Node3D
## Base dos eventos globais do SYS-004 (DD-106): AVISO (contagem) → EXECUÇÃO → CICATRIZ → pausa → de novo.
## Paz nos primeiros e últimos 25 s da partida: o evento só começa se aviso + execução couberem antes da paz final.
## A subclasse implementa os ganchos abaixo (nunca sobrescreve _ready/_process) e nasce com todos os nós prontos
## (filosofia dos Slots: nada é criado durante a partida).
## ponytail: o meteoro (6e) ainda tem o ciclo próprio; migra para esta base quando precisar mexer nele.

@export var min_seconds_between := 60.0
@export var max_seconds_between := 110.0
@export var quiet_after_start_seconds := 25.0
@export var quiet_before_end_seconds := 25.0
@export var warning_seconds := 5.0
@export var scar_seconds := 25.0

enum State { WAITING_MATCH, COOLDOWN, WARNING, ACTIVE, SCAR }

# DD-128 — portão único dos 7 eventos (o meteoro também usa): GDMD cap.03 parte 07 "eventos respeitam limite simultâneo".
# No máximo MAX_SIMULTANEOUS em AVISO/EXECUÇÃO e uma folga depois de cada execução (a cicatriz de um evento pode
# coexistir com o aviso do próximo). Um evento que esgotou o cooldown mas achou o portão fechado espera a sua vez.
const MAX_SIMULTANEOUS := 1
static var gate_gap_seconds := 25.0   # (var para o teste encurtar)
static var _running := 0
const LATE_PACE := 0.5                # SYS-004 BALANCEAMENTO "a intensidade aumenta": no fim da partida o intervalo cai à metade
static var _gap_left := 0.0
static var _gap_frame := -1


static func gate_open() -> bool:
	return _running < MAX_SIMULTANEOUS and _gap_left <= 0.0


static func gate_enter() -> void:
	_running += 1


static func gate_leave() -> void:
	_running = maxi(0, _running - 1)
	_gap_left = gate_gap_seconds


static func gate_reset() -> void:
	_running = 0
	_gap_left = 0.0


## Todo evento chama a cada quadro; só a primeira chamada do quadro desconta a folga (são vários relógios, um tempo só).
static func gate_tick(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame != _gap_frame:
		_gap_frame = frame
## Fator do intervalo entre eventos: 1 no começo da partida, LATE_PACE no fim (linear). Os eventos de ciclo próprio (meteoro) usam também.
static func pace(tree: SceneTree, seconds_left: int) -> float:
	var timer := tree.get_first_node_in_group("match_timer") as MatchTimer
	return 1.0 if timer == null else lerpf(1.0, LATE_PACE, clampf(1.0 - seconds_left / timer.duration_seconds, 0.0, 1.0))


		_gap_left = maxf(0.0, _gap_left - delta)

var state := State.WAITING_MATCH
var clock := 0.0
var _cooldown_target := 0.0
var _seconds_remaining := 1 << 30
var _last_announced := -1


# --- ganchos da subclasse ---
func _event_name() -> String: return "EVENTO"            # texto do aviso (HUD)
func _active_seconds() -> float: return 0.0              # quanto a execução dura (para caber antes da paz final)
func _setup() -> void: pass                              # cria os nós uma vez
func _begin_warning() -> bool: return true               # sorteia local/direção; false cancela este ciclo
func _tick_warning(_remaining: float, _delta: float) -> void: pass
func _begin_active() -> void: pass
func _tick_active(_delta: float) -> bool: return true    # true = a execução terminou
func _begin_scar() -> void: pass                         # deixa a cicatriz e a recompensa (DD-106/108)
func _tick_scar(_life: float) -> void: pass              # life 1 → 0
func _hide() -> void: pass                               # esconde tudo (fim da cicatriz ou da partida)
func _focus_direction() -> Vector3: return Vector3.ZERO  # onde o evento está agora (direção do centro do planeta); ZERO = sem local
func _focus_heading() -> Vector3: return Vector3.ZERO    # para onde anda (tangente ao chão); ZERO = parado


func _ready() -> void:
	add_to_group("minimap_events")
	_setup()
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.match_clock_changed.connect(func(seconds: int): _seconds_remaining = seconds)


func _process(delta: float) -> void:
	gate_tick(delta)
	match state:
		State.COOLDOWN:
			clock += delta
			if clock >= _cooldown_target:
				if not gate_open():
					_cooldown_target = clock + randf_range(0.0, 8.0)   # DD-128: fila sorteada (senão vence sempre o 1º da árvore)
				elif _seconds_remaining > quiet_before_end_seconds + warning_seconds + _active_seconds():
					_start_warning()
		State.WARNING:
			clock += delta
			var remaining := warning_seconds - clock
			var whole := maxi(0, ceili(remaining))
			if whole != _last_announced:
				_last_announced = whole
				EventBus.global_event_warning.emit(_event_name(), whole)
			_tick_warning(remaining, delta)
			if remaining <= 0.0:
				state = State.ACTIVE
				clock = 0.0
				EventBus.global_event_active_changed.emit(true)
				_begin_active()
		State.ACTIVE:
			clock += delta
			if _tick_active(delta):
				EventBus.global_event_active_changed.emit(false)
				gate_leave()
				state = State.SCAR
				clock = 0.0
				_begin_scar()
		State.SCAR:
			clock += delta
			var life := clampf(1.0 - clock / scar_seconds, 0.0, 1.0)
			_tick_scar(life)
			if life <= 0.0:
				_hide()
				_begin_cooldown()


## Onde o evento está, para o minimapa (MP-003/005): vazio fora de aviso/execução ou sem local definido.
func minimap_focus() -> Dictionary:
	if state != State.WARNING and state != State.ACTIVE:
		return {}
	var spot := _focus_direction()
	if spot == Vector3.ZERO:
		return {}
	return {"direction": spot.normalized(), "heading": _focus_heading()}


func _on_match_started() -> void:
	gate_reset()
	_begin_cooldown()
	_cooldown_target = maxf(_cooldown_target, quiet_after_start_seconds)   # DD-106: paz inicial


func _on_match_ended() -> void:
	gate_reset()
	if state == State.ACTIVE:
		EventBus.global_event_active_changed.emit(false)
	_hide()
	state = State.WAITING_MATCH


func _begin_cooldown() -> void:
	state = State.COOLDOWN
	clock = 0.0
	_cooldown_target = randf_range(min_seconds_between, max_seconds_between) * pace(get_tree(), _seconds_remaining)


func _start_warning() -> void:
	if Services.planet == null or not _begin_warning():
		_begin_cooldown()
		return
	gate_enter()
	state = State.WARNING
	clock = 0.0
	_last_announced = -1


# Disco achatado deitado no chão (sombra, cratera, poça...): "cima" do disco = normal do planeta no ponto.
func make_disc(disc_name: String, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 32
	mesh.rings = 1
	mesh.material = _unshaded(color)
	var disc := MeshInstance3D.new()
	disc.name = disc_name
	disc.mesh = mesh
	disc.visible = false
	add_child(disc)
	return disc


func place_disc(disc: MeshInstance3D, direction: Vector3, diameter: float) -> void:
	var planet := Services.planet
	var point: Vector3 = planet.center + direction * (planet.get_surface_radius(direction) + 0.25)
	disc.global_transform = Transform3D(ground_basis(direction), point)
	disc.scale = Vector3(diameter, 0.15, diameter)
	disc.visible = true


## Base com o "cima" apontando para fora do planeta em `direction` (para discos, cones, qualquer coisa de pé no chão).
func ground_basis(direction: Vector3) -> Basis:
	var right := direction.cross(Vector3.FORWARD if absf(direction.y) > 0.99 else Vector3.UP).normalized()
	return Basis(right, direction, right.cross(direction))


## Ponto no chão (superfície real) na direção `direction` a partir do centro do planeta.
func ground_point(direction: Vector3) -> Vector3:
	var planet := Services.planet
	return planet.center + direction * planet.get_surface_radius(direction)


## Direção aleatória (uniforme na esfera) a partir do centro do planeta.
func random_direction() -> Vector3:
	return Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()


## Direção de um ponto a entre `min_distance` e `max_distance` u (pelo chão) de um corredor em campo sorteado;
## sem corredor em campo, qualquer lugar do planeta.
func spot_near_runner(min_distance: float, max_distance: float) -> Vector3:
	var live := get_tree().get_nodes_in_group("runners").filter(func(n): return (n as PlanetRunner).is_active_in_field())
	if live.is_empty():
		return random_direction()
	var planet := Services.planet
	var unit: Vector3 = ((live.pick_random() as Node3D).global_position - planet.center).normalized()
	var axis := unit.cross(random_direction())
	if axis.is_zero_approx():
		return unit
	return unit.rotated(axis.normalized(), randf_range(min_distance, max_distance) / planet.radius)


func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
