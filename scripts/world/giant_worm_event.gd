class_name GiantWormEvent
extends GlobalEvent
## SYS-004 / DD-107: o VERME GIGANTE. AVISO: só a contagem (o verme está debaixo da terra) → EXECUÇÃO: de 6 a 10 saltos,
## um de cada vez: o chão INCHA no alvo (um monte cresce e três anéis mostram a zona de dano) → o verme IRROMPE e
## mergulha de novo. Dano igual ao do meteoro, pelo mesmo sinal: em cima 4 pts + volta à base | perto 2 | borda 1
## (quem aplica é o Health, ouvindo radial_damage). → CICATRIZ: montes de terra com o buraco do túnel em cima (DD-108)
## + cristais (DD-106). Nunca mexe no território (DD-024).
## ponytail: o "túnel" é só o buraco escuro no topo de cada monte (um túnel contínuo entre saltos atravessaria o
## planeta); cada alvo nasce perto de um corredor ao começar o salto (não no aviso), senão ele só sai andando.

const EVENT_NAME := "VERME GIGANTE IMINENTE"
const JUMPS := 10                                  # tamanho do pool = máximo de saltos
const PH_SWELL := 0
const PH_BURST := 1
const PH_DIVE := 2
const PH_GAP := 3
const NO_TARGET := Vector3.ZERO
const MOUND_SIZE := Vector3(6.0, 1.6, 6.0)         # tronco de cone: topo = 60 % da base
const HOLE_DIAMETER := 3.0
const WORM_RADIUS := 1.8
const WORM_LENGTH := 14.0
const WORM_PEAK := 4.0                             # altura do centro do corpo no auge do salto
const ZONE_LIFT := 0.06                            # cada anel fica um pouco acima do maior (sem z-fighting)

@export var min_jumps := 6
@export var max_jumps := 10
@export var swell_seconds := 1.6
@export var burst_seconds := 0.4
@export var dive_seconds := 0.5
@export var gap_seconds := 0.5
@export var inner_radius := 3.0
@export var mid_radius := 6.0
@export var outer_radius := 9.0
@export var jump_range := 25.0                     # u (pelo chão) entre um corredor e o alvo do salto

var jump_count := 0
var jump := 0                                      # salto atual (0 .. jump_count-1)
var phase := PH_SWELL
var _phase_t := 0.0
var _target: Array[Vector3] = []
var _mounds: Array[MeshInstance3D] = []
var _holes: Array[MeshInstance3D] = []
var _zones: Array[MeshInstance3D] = []             # 0 borda, 1 perto, 2 em cima
var _worm: MeshInstance3D


func _event_name() -> String:
	return EVENT_NAME


func _active_seconds() -> float:
	return mini(max_jumps, JUMPS) * (swell_seconds + burst_seconds + dive_seconds + gap_seconds)


func _setup() -> void:
	var mound_mesh := CylinderMesh.new()
	mound_mesh.top_radius = 0.3
	mound_mesh.bottom_radius = 0.5
	mound_mesh.height = 1.0
	mound_mesh.radial_segments = 12
	mound_mesh.rings = 1
	mound_mesh.material = _unshaded(Color(0.38, 0.26, 0.15))
	for i in JUMPS:
		var mound := MeshInstance3D.new()
		mound.name = "Mound%d" % i
		mound.mesh = mound_mesh
		mound.visible = false
		add_child(mound)
		_mounds.append(mound)
		_holes.append(make_disc("Hole%d" % i, Color(0.04, 0.02, 0.01)))
		_target.append(NO_TARGET)
	var zone_colors := [Color(0.95, 0.8, 0.2), Color(0.95, 0.5, 0.15), Color(0.85, 0.15, 0.1)]
	for k in zone_colors.size():
		_zones.append(make_disc("Zone%d" % k, zone_colors[k]))
	var worm_mesh := CapsuleMesh.new()
	worm_mesh.radius = WORM_RADIUS
	worm_mesh.height = WORM_LENGTH
	worm_mesh.radial_segments = 12
	worm_mesh.rings = 4
	worm_mesh.material = _unshaded(Color(0.5, 0.28, 0.35))
	_worm = MeshInstance3D.new()
	_worm.name = "Worm"
	_worm.mesh = worm_mesh
	_worm.visible = false
	add_child(_worm)


func _begin_warning() -> bool:
	plan([], randi_range(min_jumps, max_jumps))
	print("[World] VERME GIGANTE iminente: %d saltos (DD-107)" % jump_count)
	return true


## Fixa quantos saltos (1 a JUMPS) e, opcionalmente, o alvo de cada um (vetores a partir do centro do planeta; o que
## faltar é sorteado perto de um corredor quando o salto começa). Também usada pelos testes.
func plan(targets: Array, count: int) -> void:
	_hide()
	jump_count = clampi(count, 1, JUMPS)
	for i in JUMPS:
		_target[i] = (targets[i] as Vector3).normalized() if i < targets.size() else NO_TARGET


func _begin_active() -> void:
	jump = 0
	_begin_jump()


func _tick_active(delta: float) -> bool:
	_phase_t += delta
	var direction := _target[jump]
	match phase:
		PH_SWELL:
			_place_mound(jump, lerpf(0.2, 1.0, clampf(_phase_t / swell_seconds, 0.0, 1.0)))   # o chão incha
			if _phase_t >= swell_seconds:
				_set_phase(PH_BURST)
				_place_hole(jump, 1.0)
				EventBus.radial_damage.emit(ground_point(direction), inner_radius, 4, true, mid_radius, 2, outer_radius, 1)
		PH_BURST:
			_place_worm(direction, lerpf(-WORM_LENGTH * 0.5, WORM_PEAK, clampf(_phase_t / burst_seconds, 0.0, 1.0)))
			if _phase_t >= burst_seconds:
				_set_phase(PH_DIVE)
				for zone in _zones:
					zone.visible = false
		PH_DIVE:
			_place_worm(direction, lerpf(WORM_PEAK, -WORM_LENGTH * 0.5, clampf(_phase_t / dive_seconds, 0.0, 1.0)))
			if _phase_t >= dive_seconds:
				_worm.visible = false
				if jump + 1 >= jump_count:
					return true
				_set_phase(PH_GAP)
		PH_GAP:
			if _phase_t >= gap_seconds:
				jump += 1
				_begin_jump()
	return false


func _begin_scar() -> void:
	EventBus.bonus_drop_requested.emit(ground_point(_target[jump_count - 1]), randi_range(2, 3))   # o verme deixa cristais
	print("[World] O verme mergulhou: montes de terra e túneis (DD-108).")


func _tick_scar(life: float) -> void:
	for i in jump_count:
		_place_mound(i, maxf(life, 0.02))
		_place_hole(i, maxf(life, 0.02))


func _hide() -> void:
	for node in _mounds + _holes + _zones:
		node.visible = false
	_worm.visible = false


func _begin_jump() -> void:
	if _target[jump] == NO_TARGET:
		_target[jump] = spot_near_runner(0.0, jump_range)
	var direction := _target[jump]
	_set_phase(PH_SWELL)
	var radii := [outer_radius, mid_radius, inner_radius]
	for k in _zones.size():
		place_disc(_zones[k], direction, radii[k] * 2.0)
		_zones[k].global_position += direction * ZONE_LIFT * k
	_place_mound(jump, 0.2)


func _set_phase(next: int) -> void:
	phase = next
	_phase_t = 0.0


# Monte de terra `i` com `s` (0..1) do tamanho cheio, apoiado no chão.
func _place_mound(i: int, s: float) -> void:
	var direction := _target[i]
	var size := MOUND_SIZE * s
	_mounds[i].global_transform = Transform3D(ground_basis(direction), ground_point(direction) + direction * size.y * 0.5)
	_mounds[i].scale = size
	_mounds[i].visible = true


# Buraco do túnel no topo do monte `i`.
func _place_hole(i: int, s: float) -> void:
	var direction := _target[i]
	var diameter := HOLE_DIAMETER * s
	_holes[i].global_transform = Transform3D(ground_basis(direction), ground_point(direction) + direction * (MOUND_SIZE.y * s + 0.05))
	_holes[i].scale = Vector3(diameter, 0.1, diameter)
	_holes[i].visible = true


func _place_worm(direction: Vector3, height: float) -> void:
	_worm.global_transform = Transform3D(ground_basis(direction), ground_point(direction) + direction * height)
	_worm.visible = true
