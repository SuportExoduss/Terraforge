extends SceneTree
## Fotografa a ONDA de dominação (DD-127; exige janela, sem --headless): a calota do jogador cresce e a pintura sobe do
## território antigo para a borda nova. Uma foto a cada ~0,15 s de jogo depois do anúncio.
## Uso: godot_console --path . --fixed-fps 60 --resolution 960x540 -s res://tools/shot_wave.gd -- <pasta de saída>

const SHOT_FRAMES := [4, 10, 18, 27, 38, 52, 80]
var _main: Node
var _frame := -1
var _out := ""


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
		painter.paint_all_now()
		map.claim_cap(1, Vector3.UP, 0.75)   # cresce de 0,35 (calota inicial) para 0,75 rad
		var cam: Camera3D = _main.get_node("Camera")
		cam.global_position = Vector3(0.0, 1.0, 0.35).normalized() * 230.0
		cam.look_at(Vector3(0, 100, 0), Vector3.FORWARD)
		_frame = 0
		return false
	_frame += 1
	if _frame in SHOT_FRAMES:
		var path := "%s/onda_%02d.png" % [_out, SHOT_FRAMES.find(_frame)]
		root.get_texture().get_image().save_png(path)
		print("foto ", path, " pendentes=", painter.pending_cells())
	if _frame > SHOT_FRAMES[-1]:
		quit(0)
	return false
