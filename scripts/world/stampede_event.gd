class_name StampedeEvent
extends GlobalEvent
## SYS-004 / DD-107: a MANADA ("cruza uma região em alta velocidade, atropela jogadores"). AVISO: a faixa por onde a
## manada vai passar acende no chão (círculo máximo) e a contagem corre → EXECUÇÃO: 5 touros em V (o líder na ponta)
## correm pela faixa; quem estiver no caminho leva 3 pts e volta à base (2 s de folga, como no Furacão) → CICATRIZ:
## pegadas que somem aos poucos (DD-108) + bônus no ponto onde parou (DD-106). Nunca mexe no território (DD-024).
## ponytail: o touro é o do defensor (esqueleto, anima Trot) em tamanho maior; a faixa é uma fila de
## caixas planas (a borda flutua ~0,5 u no chão curvo); a manada não arrasa obstáculos.

const EVENT_NAME := "MANADA SE APROXIMANDO"
const BULLS := 5
const V := [Vector2(0.0, 0.0), Vector2(-3.5, -4.0), Vector2(3.5, -4.0), Vector2(-7.0, -8.0), Vector2(7.0, -8.0)]   # (lado, à frente) em u
const SIZE_FACTOR := 1.5                           # vezes o touro defensor
const LANE_WIDTH := 20.0                           # = faixa dos touros (±7 u) + raio de pisada (3 u)
const LANE_SEGMENTS := 14
const PRINTS := 20
const MARGIN := 10.0                               # u de faixa antes da largada e depois da chegada

@export var run_seconds := 6.0
@export var speed := 22.0                          # u/s pelo chão
@export var hit_radius := 3.0
@export var damage := 3

var _start := Vector3.UP                           # onde a cabeça da manada larga
var _heading := Vector3.RIGHT                      # para onde corre (tangente em _start)
var _bulls: Array[Node3D] = []
var _bull_dirs: Array[Vector3] = []
var _lane: Array[MeshInstance3D] = []
var _prints: Array[MeshInstance3D] = []
var _sent := {}                                    # id do corredor -> quando foi atropelado


func _event_name() -> String:
	return EVENT_NAME


func _active_seconds() -> float:
	return run_seconds


func _setup() -> void:
	var lane_material := _unshaded(Color(0.95, 0.7, 0.2, 0.4))
	lane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var box := BoxMesh.new()
	box.material = lane_material
	for i in LANE_SEGMENTS:
		var segment := MeshInstance3D.new()
		segment.name = "Lane%d" % i
		segment.mesh = box
		segment.visible = false
		add_child(segment)
		_lane.append(segment)
	for i in PRINTS:
		_prints.append(make_disc("Print%d" % i, Color(0.22, 0.15, 0.09)))
	var model := load(DefenderSystem.BULL_PATH) as PackedScene   # load(): preload de .glb quebra o carregamento da partida
	for i in BULLS:
		var bull := Node3D.new()
		bull.name = "Bull%d" % i
		var body := model.instantiate() as Node3D
		body.scale = Vector3.ONE * DefenderSystem.BULL_SCALE * SIZE_FACTOR
		bull.add_child(body)
		bull.visible = false
		add_child(bull)
		_bulls.append(bull)
		_bull_dirs.append(Vector3.UP)
		var anim := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.get_animation("Trot").loop_mode = Animation.LOOP_LINEAR
		anim.speed_scale = 3.0


func _begin_warning() -> bool:
	var target := spot_near_runner(0.0, 20.0)   # a faixa passa (no meio) perto de alguém
	var heading := target.cross(random_direction())
	var axis := target.cross(heading).normalized()
	var back := -speed * run_seconds * 0.5 / Services.planet.radius
	plan(target.rotated(axis, back), heading.rotated(axis, back))
	GameLog.say("[World] MANADA se aproximando! (DD-107)")
	return true


## Fixa onde a cabeça da manada larga e para onde corre (também usada pelos testes).
func plan(start: Vector3, heading: Vector3) -> void:
	_hide()
	_start = start.normalized()
	_heading = heading.slide(_start).normalized()
	_sent.clear()
	var length := speed * run_seconds + MARGIN * 2.0
	var step := length / LANE_SEGMENTS
	for k in LANE_SEGMENTS:
		var at := _at(-MARGIN + (k + 0.5) * step)
		var dir: Vector3 = at[0]
		var planet := Services.planet
		_lane[k].global_transform = Transform3D(_frame(dir, at[1]), planet.center + dir * (planet.get_surface_radius(dir) + 0.35))
		_lane[k].scale = Vector3(LANE_WIDTH, 0.1, step * 1.08)
		_lane[k].visible = true


func _begin_active() -> void:
	for i in BULLS:
		_bulls[i].visible = true
		var anim := _bulls[i].get_child(0).find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("Trot")
		anim.seek(i * 0.17)   # cada touro numa passada
	_place_bulls()


func _tick_active(_delta: float) -> bool:
	_place_bulls()
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		if runner.is_active_in_field():
			_trample(runner)
	return clock >= run_seconds


func _begin_scar() -> void:
	for lane in _lane:
		lane.visible = false
	for bull in _bulls:
		bull.visible = false
	var span := speed * run_seconds
	for i in PRINTS:
		var at := _at((i + 0.5) * span / PRINTS)
		place_disc(_prints[i], _spot(at[0], at[1], V[i % BULLS]), 2.0)
	EventBus.bonus_drop_requested.emit(ground_point(_at(span)[0]), randi_range(2, 3))
	GameLog.say("[World] A manada passou: pegadas no chão (DD-108).")


func _tick_scar(life: float) -> void:
	var s := 2.0 * maxf(life, 0.02)
	for p in _prints:
		p.scale = Vector3(s, 0.15, s)


func _hide() -> void:
	for group in [_lane, _prints, _bulls]:
		for node in group:
			node.visible = false


## Quem estiver a `hit_radius` u (pelo chão) de algum touro leva `damage` e volta à base; 2 s de folga por corredor.
func _trample(runner: PlanetRunner) -> void:
	var planet := Services.planet
	var unit := (runner.global_position - planet.center).normalized()
	var id := runner.get_instance_id()
	var health := runner.get_node_or_null("Health") as Health
	if health == null or clock - _sent.get(id, -99.0) <= 2.0:
		return
	for dir in _bull_dirs:
		if acos(clampf(unit.dot(dir), -1.0, 1.0)) * planet.radius <= hit_radius:
			_sent[id] = clock
			health.take_damage(damage, "MANADA")
			if health.points > 0:
				health.return_to_force_field()
			return


# Ponto do círculo máximo da manada a `d` u da largada: [direção, tangente de marcha].
func _at(d: float) -> Array:
	var angle := d / Services.planet.radius
	var axis := _start.cross(_heading)
	return [_start.rotated(axis, angle), _heading.rotated(axis, angle)]


# Onde fica o touro `v` (lado, à frente) em relação à cabeça da manada.
func _spot(head: Vector3, heading: Vector3, v: Vector2) -> Vector3:
	return (head + (heading * v.y + heading.cross(head) * v.x) / Services.planet.radius).normalized()


# Base de pé no chão em `dir`, com +Z (a frente do modelo do touro) apontando para `heading`.
func _frame(dir: Vector3, heading: Vector3) -> Basis:
	var z := heading.slide(dir).normalized()
	return Basis(dir.cross(z), dir, z)


func _place_bulls() -> void:
	var at := _at(speed * clock)
	for i in BULLS:
		var dir := _spot(at[0], at[1], V[i])
		_bull_dirs[i] = dir
		_bulls[i].global_transform = Transform3D(_frame(dir, at[1]), ground_point(dir))


func _focus_direction() -> Vector3:
	return _at(speed * clock if state == State.ACTIVE else speed * run_seconds * 0.5)[0]   # no aviso: o meio da faixa


func _focus_heading() -> Vector3:
	return _at(speed * clock if state == State.ACTIVE else speed * run_seconds * 0.5)[1]
