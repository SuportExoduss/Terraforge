class_name PlanetBackdrop
extends SubViewportContainer
## Abertura viva (Cap.03 P01, DD-006: "a primeira impressão deve ser o planeta, nunca a interface"): o fundo do menu é
## o planeta girando devagar, com nuvens que andam mais rápido que o chão, atmosfera, estrelas, auroras ocasionais no polo
## e meteoros riscando o fundo. Mundo 3D próprio (SubViewport), então não toca na partida; o mouse passa direto para o menu.
## ponytail: planeta cru (sem pintura de território) e sorteios sem semente; só o aspecto, nada aqui vale para a partida.

const PLANET_MODEL := "res://art/models/planet/Planet_Base.glb"
const RADIUS := 10.0
const TILT := 0.41                        # inclinação do eixo (rad)
const SPIN := 0.07                        # rad/s do planeta
const CLOUD_SPIN := 0.11                  # rad/s das nuvens (mais rápidas: o céu anda sobre o chão)
const STARS := 260
const METEOR_GAP := Vector2(2.5, 7.0)     # s entre meteoros
const METEOR_LIFE := 1.1
const AURORA_GAP := Vector2(9.0, 20.0)    # s entre auroras
const AURORA_SECONDS := 9.0
const CAMERA_HOME := Vector3(0.0, 8.5, 45.0)   # vista do menu
const LOOK_HOME := Vector3(0.0, 8.5, 0.0)
const CAMERA_DIVE := Vector3(0.0, 0.0, 10.7)   # entre as nuvens (r 10,4) e a atmosfera (r 11,3), olhando o chão

const CLOUD_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
varying vec3 obj;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1, 0, 0)), f.x), mix(h(i + vec3(0, 1, 0)), h(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(h(i + vec3(0, 0, 1)), h(i + vec3(1, 0, 1)), f.x), mix(h(i + vec3(0, 1, 1)), h(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { obj = VERTEX; }
void fragment() {
	vec3 p = normalize(obj) * 3.5;
	float v = n(p) * 0.55 + n(p * 2.1) * 0.3 + n(p * 4.3) * 0.15;
	ALBEDO = vec3(0.95, 0.97, 1.0);
	ROUGHNESS = 1.0;
	ALPHA = smoothstep(0.5, 0.68, v) * 0.85;
}
"""

const ATMOSPHERE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;
uniform vec3 tint = vec3(0.35, 0.65, 1.0);
uniform float boost = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	ALBEDO = tint * boost;
	ALPHA = rim;
}
"""

const AURORA_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
uniform float strength = 0.0;
void fragment() {
	float wave = sin(UV.x * 40.0 + TIME * 0.7) * 0.5 + sin(UV.x * 17.0 - TIME * 0.4) * 0.5;
	float curtain = 0.55 + 0.45 * wave;
	float fall = pow(1.0 - UV.y, 1.6);
	vec3 tint = mix(vec3(0.1, 1.0, 0.55), vec3(0.65, 0.3, 1.0), UV.y);
	ALBEDO = tint;
	ALPHA = curtain * fall * strength;
}
"""

var camera: Camera3D
var spinner: Node3D       # o planeta (gira)
var clouds: Node3D        # a casca de nuvens (gira mais rápido)
var atmosphere: MeshInstance3D
var aurora: MeshInstance3D
var meteors_spawned := 0
var auroras_shown := 0
var running := true        # falso: o fundo congela (ex.: durante o carregamento)
var diving := false        # verdadeiro depois de approach(): a câmera está descendo para a partida

var _viewport: SubViewport
var _stage: Node3D
var _atmo_material: ShaderMaterial
var _aurora_material: ShaderMaterial
var _meteor_clock := 3.0
var _aurora_clock := 6.0
var _aurora_age := -1.0    # < 0: apagada
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	_viewport = SubViewport.new()
	_viewport.name = "SubViewport"
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_stage = Node3D.new()
	_stage.name = "Stage"
	_viewport.add_child(_stage)
	_build_environment()
	_build_planet()
	_build_stars()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 40.0
	_stage.add_child(camera)
	camera.position = CAMERA_HOME   # planeta baixo na tela: o título e o perfil ficam acima dele
	camera.look_at(LOOK_HOME)
	camera.current = true


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	_stage.add_child(sun)
	sun.rotation = Vector3(-0.35, 0.9, 0.0)


func _build_planet() -> void:
	var tilt := Node3D.new()      # eixo inclinado; as nuvens e o planeta giram em volta dele
	tilt.name = "Tilt"
	tilt.rotation = Vector3(0.5, 0.0, TILT)   # o polo norte vira para a câmera: a aurora fica à vista
	_stage.add_child(tilt)
	spinner = Node3D.new()
	spinner.name = "Planet"
	tilt.add_child(spinner)
	var model := (load(PLANET_MODEL) as PackedScene).instantiate() as Node3D
	spinner.add_child(model)
	var box := ModelUtils.local_aabb(model)
	var half := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.5
	if half > 0.0:
		model.scale *= RADIUS / half
	clouds = Node3D.new()
	clouds.name = "Clouds"
	tilt.add_child(clouds)
	clouds.add_child(_shell(RADIUS * 1.04, CLOUD_SHADER))
	atmosphere = _shell(RADIUS * 1.13, ATMOSPHERE_SHADER)
	atmosphere.name = "Atmosphere"
	tilt.add_child(atmosphere)
	_atmo_material = atmosphere.material_override as ShaderMaterial
	_build_aurora(tilt)


func _shell(radius: float, shader_code: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 64
	mesh.rings = 32
	var shell := MeshInstance3D.new()
	shell.mesh = mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = shader_code
	shell.material_override = material
	return shell


## Cortina de aurora: um tubo aberto em volta do polo norte, perto de 66° de latitude.
func _build_aurora(parent: Node3D) -> void:
	var tube := CylinderMesh.new()
	var ring := RADIUS * 0.41 * 1.03
	tube.top_radius = ring
	tube.bottom_radius = ring
	tube.height = RADIUS * 0.22
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 96
	aurora = MeshInstance3D.new()
	aurora.name = "Aurora"
	aurora.mesh = tube
	aurora.position.y = RADIUS * 0.91
	aurora.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aurora_material = ShaderMaterial.new()
	_aurora_material.shader = Shader.new()
	_aurora_material.shader.code = AURORA_SHADER
	aurora.material_override = _aurora_material
	aurora.visible = false
	parent.add_child(aurora)


func _build_stars() -> void:
	var points := PackedVector3Array()
	for i in STARS:
		var dir := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()).normalized()
		points.append(dir * 90.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.use_point_size = true
	material.point_size = 2.0
	material.albedo_color = Color(0.85, 0.9, 1.0)
	var stars := MeshInstance3D.new()
	stars.name = "Stars"
	stars.mesh = mesh
	stars.material_override = material
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(stars)


func _process(delta: float) -> void:
	if not running:
		return
	spinner.rotate_y(SPIN * delta)
	clouds.rotate_y(CLOUD_SPIN * delta)
	_meteor_clock -= delta
	if _meteor_clock <= 0.0:
		spawn_meteor()
		_meteor_clock = _rng.randf_range(METEOR_GAP.x, METEOR_GAP.y)
	_aurora_clock -= delta
	if _aurora_clock <= 0.0 and _aurora_age < 0.0:
		show_aurora()
		_aurora_clock = _rng.randf_range(AURORA_GAP.x, AURORA_GAP.y)
	_tick_aurora(delta)


## Um meteoro risca o fundo (atrás do planeta): nasce no alto de um lado e cai para o outro, sumindo no caminho.
func spawn_meteor() -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var streak := MeshInstance3D.new()
	streak.name = "Meteor"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 4.0)
	streak.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.8, 0.5)
	streak.material_override = material
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(streak)
	var start := Vector3(-side * _rng.randf_range(16.0, 26.0), _rng.randf_range(10.0, 17.0), _rng.randf_range(-34.0, -18.0))
	var velocity := Vector3(side * 26.0, -13.0, 0.0)
	streak.position = start
	streak.look_at(start + velocity)
	meteors_spawned += 1
	var tween := streak.create_tween()
	tween.tween_property(streak, "position", start + velocity * METEOR_LIFE, METEOR_LIFE)
	tween.parallel().tween_property(streak, "scale", Vector3(0.1, 0.1, 0.1), METEOR_LIFE).set_ease(Tween.EASE_IN)
	tween.tween_callback(streak.queue_free)


## Primeiro clique em JOGAR (DD-007: nunca uma tela estática): a câmera desce até o planeta, atravessa a atmosfera
## (que brilha) e as nuvens, e a imagem escurece no fim. Termina em `seconds`; a partida carrega por baixo.
func approach(seconds: float) -> void:
	diving = true
	var tween := create_tween()
	tween.tween_method(_dive, 0.0, 1.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished


func _dive(t: float) -> void:
	camera.position = CAMERA_HOME.lerp(CAMERA_DIVE, t)
	camera.look_at(LOOK_HOME.lerp(Vector3.ZERO, t))
	_atmo_material.set_shader_parameter("boost", 1.0 + 4.0 * t)
	modulate = Color.WHITE.lerp(Color.BLACK, smoothstep(0.8, 1.0, t))


func show_aurora() -> void:
	_aurora_age = 0.0
	aurora.visible = true
	auroras_shown += 1


## A aurora acende e apaga suavemente ao longo de AURORA_SECONDS.
func aurora_strength() -> float:
	return 0.0 if _aurora_age < 0.0 else sin(clampf(_aurora_age / AURORA_SECONDS, 0.0, 1.0) * PI) * 0.9


func _tick_aurora(delta: float) -> void:
	if _aurora_age < 0.0:
		return
	_aurora_age += delta
	if _aurora_age >= AURORA_SECONDS:
		_aurora_age = -1.0
		aurora.visible = false
	_aurora_material.set_shader_parameter("strength", aurora_strength())
