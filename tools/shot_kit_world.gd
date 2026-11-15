extends SceneTree
## Fotografa o planeta com o kit de bioma da civilização escolhida já revelado (densidade 100 % só nesta execução) — exige janela.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_kit_world.gd -- <pasta de saída> <civilização 2-6>

var _main: Node
var _slots: Node
var _frame := 0
var _time := 0.0
var _out := ""
var _civ := 2
var _stage := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # autoloads prontos
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_civ = int(args[1]) if args.size() > 1 else 2
	load("res://scripts/core/profile.gd").data["civilization"] = _civ   # só na memória: o registro de fichas lê isto ao entrar na cena
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("HomeBase").skip_ceremony()
	root.add_child(_main)
	_slots = _main.get_node("Slots")
	var t = root.get_node("Services").themes.theme_of(1)
	t.vegetation_density = 1.0
	t.rock_density = 1.0
	print("civilização ativa: ", t.civilization_name, " kit=", t.procedural_kit)


func _process(delta: float) -> bool:
	if _main == null:
		return false
	_frame += 1
	_time += delta
	var planet: Node3D = _main.get_node("Planet")
	var cam: Camera3D = _main.get_node("Camera")
	if _stage == 0:
		if not planet.surface_ready or _main.get_node("Territory")._counts[1] == 0:
			return _frame > 900
		cam.set_process(false)
		_main.get_node("Territory").claim_cap(1, Vector3.UP, 0.9)
		planet.get_node("Painter").paint_all_now()
		_stage = 1
		_time = 0.0
		return false
	if _stage == 1 and _time > 2.0:
		print("revelados=", _slots.revealed_count(1, false))
		cam.global_position = Vector3(60.0, 230.0, 40.0)
		cam.look_at(Vector3(0.0, 100.0, 0.0), Vector3.UP)
		_stage = 2
		_time = 0.0
	elif _stage == 2 and _time > 0.4:
		print("foto largo erro=", root.get_texture().get_image().save_png("%s/mundo_civ%d_largo.png" % [_out, _civ]))
		cam.global_position = Vector3(20.0, 120.0, 40.0)
		cam.look_at(Vector3(0.0, 100.0, 0.0), Vector3.UP)
		_stage = 3
		_time = 0.0
	elif _stage == 3 and _time > 0.4:
		print("foto perto erro=", root.get_texture().get_image().save_png("%s/mundo_civ%d_perto.png" % [_out, _civ]))
		quit(0)
	return false
