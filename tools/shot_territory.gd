extends SceneTree
## Fotografa a BORDA do território de perto e de longe (exige janela, sem --headless).
## Uso: godot_console --path . --fixed-fps 60 --resolution 960x540 -s res://tools/shot_territory.gd -- <pasta de saída>

const EDGE := 0.75   # raio da calota (rad)
var _main: Node
var _frame := -1
var _out := ""
# [afastamento da superfície, deslocamento para dentro do território (u), nome]
var _shots := [[14.0, 6.0, "perto"], [30.0, 8.0, "medio"], [75.0, 0.0, "longe"]]
var _step := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("HomeBase").skip_ceremony()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var map: Node = _main.get_node("Territory")
	var painter = _main.get_node("Planet/Painter")
	if _frame < 0:
		if map._counts[1] == 0:
			return false
		_main.get_node("Camera").set_process(false)
		map.claim_cap(1, Vector3.UP, EDGE)
		_frame = 0
		return false
	_frame += 1
	if _frame == 3:
		painter.paint_all_now()
	if _frame < 30:
		return false
	var s: Array = _shots[_step]
	var edge := Vector3(sin(EDGE), cos(EDGE), 0.0)                       # ponto da borda
	var inward := Vector3(cos(EDGE), -sin(EDGE), 0.0)                     # tangente apontando para dentro do território (sentido do polo)
	inward = -inward
	var base: Vector3 = (edge * 100.0) + inward * (s[1] as float)
	var cam: Camera3D = _main.get_node("Camera")
	cam.global_position = base + edge * (s[0] as float) + Vector3(0, 0, 14.0)
	cam.look_at(edge * 100.0, edge)
	if _frame >= 33:
		root.get_texture().get_image().save_png("%s/%s.png" % [_out, s[2]])
		print("foto ", s[2])
		_step += 1
		_frame = 29
		if _step >= _shots.size():
			quit(0)
	return false
