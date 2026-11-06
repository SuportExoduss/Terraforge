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


func _ready() -> void:
	_setup()
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.match_clock_changed.connect(func(seconds: int): _seconds_remaining = seconds)


func _process(delta: float) -> void:
	match state:
		State.COOLDOWN:
			clock += delta
			if clock >= _cooldown_target and _seconds_remaining > quiet_before_end_seconds + warning_seconds + _active_seconds():
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
				_begin_active()
		State.ACTIVE:
			clock += delta
			if _tick_active(delta):
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


func _on_match_started() -> void:
	_begin_cooldown()
	_cooldown_target = maxf(_cooldown_target, quiet_after_start_seconds)   # DD-106: paz inicial


func _on_match_ended() -> void:
	_hide()
	state = State.WAITING_MATCH


func _begin_cooldown() -> void:
	state = State.COOLDOWN
	clock = 0.0
	_cooldown_target = randf_range(min_seconds_between, max_seconds_between)


func _start_warning() -> void:
	if Services.planet == null or not _begin_warning():
		_begin_cooldown()
		return
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


func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
