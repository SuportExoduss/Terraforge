extends SceneTree
## Fotografa os 5 kits de bioma procedurais (12 modelos cada, em 2 fileiras sobre o solo da civilização) — exige janela, sem --headless.
## Uso: godot_console --path . --resolution 1280x720 -s res://tools/shot_biome_kit.gd -- <pasta de saída>

const BiomeKit := preload("res://scripts/world/biome_kit.gd")
const HEIGHTS: Array[float] = [4.0, 2.2, 1.1, 4.5, 1.2, 1.6, 3.5, 6.5, 1.4, 2.0, 1.5, 11.0]   # as mesmas do EnvironmentSlotSystem

var _out := ""
var _frame := 0
var _stage: Node3D
var _only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_only = args[1] if args.size() > 1 else ""
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.light_energy = 1.1
	root.add_child(sun)


func _build(kit: String, civ: int) -> void:
	if _stage != null:
		_stage.queue_free()
	_stage = Node3D.new()
	root.add_child(_stage)
	var soil := Color(0.5, 0.5, 0.5)
	var theme := load("res://art/themes/theme_civ%d.tres" % civ) as PlanetTheme
	if theme != null:
		soil = theme.soil_base
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(48.0, 0.5, 22.0)
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.25, 0.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = soil
	gm.roughness = 1.0
	ground.material_override = gm
	_stage.add_child(ground)
	for i in 12:
		var inst := MeshInstance3D.new()
		var holder := (BiomeKit.scene(kit, i) as PackedScene).instantiate() as Node3D
		var mesh: Mesh = (holder.get_child(0) as MeshInstance3D).mesh
		inst.mesh = mesh
		holder.free()
		var s := HEIGHTS[i] / mesh.get_aabb().size.y
		inst.scale = Vector3.ONE * s
		inst.position = Vector3(-17.5 + (i % 6) * 7.0, 0.0, -4.0 if i < 6 else 5.0)
		_stage.add_child(inst)


func _process(_delta: float) -> bool:
	_frame += 1
	var step := _frame / 8
	var kits: Array = BiomeKit.KITS
	if _frame % 8 == 1 and step < kits.size():
		_build(kits[step], step + 2)
		var cam := get_nodes_in_group("cam")
		if cam.is_empty():
			var c := Camera3D.new()
			c.add_to_group("cam")
			c.fov = 46.0
			root.add_child(c)
			c.position = Vector3(0.0, 15.0, 33.0)
			c.look_at(Vector3(0.0, 2.6, 0.0))
	if _frame % 8 == 7 and step < kits.size():
		root.get_texture().get_image().save_png("%s/kit_%s.png" % [_out, kits[step]])
	if _frame > 8 * kits.size() + 2:
		quit(0)
	return false
