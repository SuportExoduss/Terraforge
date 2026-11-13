class_name MeteorEventSystem
extends Node3D
## SYS-004 / DD-107: o METEORO. Segue o ciclo oficial dos eventos globais (DD-106): AVISO (contagem + sombra
## crescendo no ponto de impacto) → EXECUÇÃO (a rocha cai do céu; dano em 3 anéis 4/2/1, o centro devolve a
## vítima à base — quem aplica é o Health, ouvindo radial_damage) → CICATRIZ (cratera escura que encolhe, DD-108).
## Sombra, rocha e cratera nascem UMA vez e são reaproveitadas (filosofia dos Slots: nada criado na partida).

const EVENT_NAME := "METEORO CAINDO"

@export var model: PackedScene   # a rocha (opcional: sem ela só haveria sombra e cratera)
@export var min_seconds_between := 45.0
@export var max_seconds_between := 90.0
## DD-106: paz nos primeiros e últimos 25 s da partida.
@export var quiet_after_start_seconds := 25.0
@export var quiet_before_end_seconds := 25.0
@export var warning_seconds := 5.0
@export var scar_seconds := 25.0
@export var inner_radius := 6.0
@export var mid_radius := 12.0
@export var outer_radius := 20.0
@export var rock_fall_seconds := 1.5
@export var rock_altitude := 80.0
@export var rock_diameter := 8.0
@export var rock_tumble_degrees := 220.0

enum State { WAITING_MATCH, COOLDOWN, WARNING, SCAR }

var _state := State.WAITING_MATCH
var _clock := 0.0
var _cooldown_target := 0.0
var _seconds_remaining := 1 << 30
var _last_announced := -1
var _impact_direction := Vector3.UP
var _impact_point := Vector3.ZERO
var _shadow: MeshInstance3D
var _scar: MeshInstance3D
var _rock: Node3D          # "Rock": gira e tem a escala; o modelo dentro dele é deslocado para o centro ficar na origem
var _rock_anchor: Node3D   # só posição e direção (o "cima" do chão no ponto de impacto); nunca gira
var _tail: MeshInstance3D
var _rock_scale := 1.0


func _ready() -> void:
	add_to_group("minimap_events")
	_shadow = _make_disc("Shadow", Color(0.05, 0.05, 0.08))
	_scar = _make_disc("Scar", Color(0.12, 0.07, 0.04))
	if model != null:
		_rock_anchor = Node3D.new()
		_rock_anchor.name = "RockAnchor"
		add_child(_rock_anchor)
		_rock = Node3D.new()
		_rock.name = "Rock"
		_rock.visible = false
		_rock_anchor.add_child(_rock)
		var rock_model := model.instantiate() as Node3D
		_rock.add_child(rock_model)
		var box := ModelUtils.local_aabb(rock_model)
		rock_model.position = -box.get_center()   # o centro VISUAL do modelo passa a ser a origem do pivô
		_rock_scale = rock_diameter / maxf(0.001, maxf(box.size.x, maxf(box.size.y, box.size.z)))
		_rock.scale = Vector3.ONE * _rock_scale
		_tail = _make_disc("Tail", Color(1.0, 0.55, 0.15, 0.7))   # cauda de fogo: mostra de onde a rocha vem
		((_tail.mesh as CylinderMesh).material as BaseMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.match_clock_changed.connect(func(seconds: int): _seconds_remaining = seconds)


func _process(delta: float) -> void:
	GlobalEvent.gate_tick(delta)
	match _state:
		State.COOLDOWN:
			_clock += delta
			# DD-106: o impacto precisa caber antes dos 25 s finais — sem tempo hábil, os céus se calam.
			# DD-128: e o portão dos eventos globais precisa estar aberto (um por vez).
			if _clock >= _cooldown_target:
				if not GlobalEvent.gate_open():
					_cooldown_target = _clock + randf_range(0.0, 8.0)   # DD-128: fila sorteada
				elif _seconds_remaining > quiet_before_end_seconds + warning_seconds:
					_begin_warning()
		State.WARNING:
			_update_warning(delta)
		State.SCAR:
			_update_scar(delta)


func _on_match_started() -> void:
	GlobalEvent.gate_reset()
	_begin_cooldown()
	_cooldown_target = maxf(_cooldown_target, quiet_after_start_seconds)   # DD-106: paz inicial


func _on_match_ended() -> void:
	GlobalEvent.gate_reset()
	_shadow.visible = false
	_scar.visible = false
	_hide_rock()
	_state = State.WAITING_MATCH


func _begin_cooldown() -> void:
	_state = State.COOLDOWN
	_clock = 0.0
	_cooldown_target = randf_range(min_seconds_between, max_seconds_between) * GlobalEvent.pace(get_tree(), _seconds_remaining)


## Onde o meteoro vai cair, para o minimapa (MP-003/005): só durante o aviso.
func minimap_focus() -> Dictionary:
	if _state != State.WARNING:
		return {}
	return {"direction": _impact_direction, "heading": Vector3.ZERO}


# AVISO: sorteia o ponto de impacto e a sombra começa a crescer.
func _begin_warning() -> void:
	var planet := Services.planet
	if planet == null:
		_begin_cooldown()
		return
	_impact_direction = Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()   # uniforme na esfera
	_impact_point = planet.center + _impact_direction * planet.get_surface_radius(_impact_direction)
	_place_flat(_shadow, 2.0)
	GlobalEvent.gate_enter()
	_state = State.WARNING
	_clock = 0.0
	_last_announced = -1
	GameLog.say("[World] METEORO a caminho! (DD-107)")


func _update_warning(delta: float) -> void:
	_clock += delta
	var remaining := warning_seconds - _clock
	var diameter := lerpf(2.0, inner_radius * 2.0, clampf(_clock / warning_seconds, 0.0, 1.0))   # sombra cresce
	_shadow.scale = Vector3(diameter, 0.15, diameter)

	var whole := maxi(0, ceili(remaining))
	if whole != _last_announced:
		_last_announced = whole
		EventBus.global_event_warning.emit(EVENT_NAME, whole)

	# A rocha só aparece no finalzinho, despencando do céu pela linha reta que liga o céu ao ponto de impacto.
	if _rock != null and remaining <= rock_fall_seconds:
		_place_rock(clampf(1.0 - remaining / rock_fall_seconds, 0.0, 1.0))
	if remaining <= 0.0:
		_impact()


# EXECUÇÃO: o golpe (3 anéis exclusivos) e a cicatriz.
func _impact() -> void:
	EventBus.radial_damage.emit(_impact_point, inner_radius, 4, true, mid_radius, 2, outer_radius, 1)
	_shadow.visible = false
	_hide_rock()
	_place_flat(_scar, mid_radius * 2.0)
	GlobalEvent.gate_leave()
	_state = State.SCAR
	_clock = 0.0
	EventBus.bonus_drop_requested.emit(_impact_point, randi_range(1, 3))   # RECOMPENSA do evento (DD-106, SYS-005)
	GameLog.say("[World] IMPACTO do meteoro! Cratera aberta (DD-108).")


# CICATRIZ: a cratera encolhe até sumir (DD-108, ~25 s).
func _update_scar(delta: float) -> void:
	_clock += delta
	var life := clampf(1.0 - _clock / scar_seconds, 0.0, 1.0)
	var diameter := mid_radius * 2.0 * life
	_scar.scale = Vector3(diameter, 0.12, diameter)
	if life <= 0.0:
		_scar.visible = false
		_begin_cooldown()


func _hide_rock() -> void:
	if _rock != null:
		_rock.visible = false
		_tail.visible = false


# fall 0 = no céu, 1 = no chão. A rocha SEMPRE nasce no alto da vertical do ponto de impacto (o "cima" do chão ali),
# cai em linha reta e gira no lugar; a cauda aponta de volta para o céu. Nada herda estado de uma queda anterior.
func _place_rock(fall: float) -> void:
	var up := _impact_direction
	var right := up.cross(Vector3.FORWARD if absf(up.y) > 0.99 else Vector3.UP).normalized()
	var ground := Basis(right, up, right.cross(up))
	var center := _impact_point + up * lerpf(rock_altitude, rock_diameter * 0.3, fall)
	var grow := clampf(fall / 0.15, 0.0, 1.0)   # surge crescendo no alto, sem "pipocar"
	_rock_anchor.global_transform = Transform3D(ground, center)
	_rock.basis = Basis(Vector3.ONE.normalized(), deg_to_rad(rock_tumble_degrees) * fall * rock_fall_seconds) 			* Basis.from_scale(Vector3.ONE * _rock_scale * grow)
	var tail_length := rock_diameter * 3.0 * grow
	_tail.global_transform = Transform3D(ground, center + up * (tail_length * 0.5))
	_tail.scale = Vector3(rock_diameter * 0.6 * grow, tail_length, rock_diameter * 0.6 * grow)
	_rock.visible = true
	_tail.visible = true


func _make_disc(disc_name: String, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 32
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	var disc := MeshInstance3D.new()
	disc.name = disc_name
	disc.mesh = mesh
	disc.visible = false
	add_child(disc)
	return disc


# Disco deitado sobre o chão do ponto de impacto (o "cima" do disco = normal do planeta ali).
func _place_flat(disc: MeshInstance3D, diameter: float) -> void:
	var up := _impact_direction
	var right := up.cross(Vector3.FORWARD if absf(up.y) > 0.99 else Vector3.UP).normalized()
	disc.global_transform = Transform3D(Basis(right, up, right.cross(up)), _impact_point + up * 0.25)
	disc.scale = Vector3(diameter, 0.15, diameter)
	disc.visible = true
