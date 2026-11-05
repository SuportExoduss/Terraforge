extends SceneTree
## Fotografa a nave na descida de abertura e a base pousada com o domo (exige janela).
## Uso: godot_console --path . -s res://tools/shot_base.gd -- <pasta de saída>

var _main: Node
var _out := ""
var _time := 0.0
var _step := 0
# [instante, posição da câmera, alvo, nome]
var _shots := [[2.4, Vector3(40, 132, 40), Vector3(0, 130, 0), "descida"],
		[7.6, Vector3(22, 112, 30), Vector3(0, 104, 0), "base"],
		[7.9, Vector3(0, 125, 40), Vector3(0, 100, 0), "base_alta"]]


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_main.get_node("Camera").set_process(false)


func _process(delta: float) -> bool:
	_time += delta
	if _step >= _shots.size():
		quit(0)
		return true
	var s: Array = _shots[_step]
	var cam: Camera3D = _main.get_node("Camera")
	if _time >= s[0]:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		if _time >= s[0] + 0.15:
			var img := root.get_texture().get_image()
			print("foto ", s[3], " erro=", img.save_png("%s/%s.png" % [_out, s[3]]))
			_step += 1
	return false
