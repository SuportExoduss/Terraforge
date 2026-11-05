extends SceneTree
## Fotografa a partida com bots: (1) a câmera do jogador; (2) o planeta visto de cima de cada base.
## Exige janela. Uso: godot_console --path . -s res://tools/shot_match.gd -- <pasta de saída>

var _match: Node
var _out := ""
var _time := 0.0
var _step := 0


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	root.add_child(_match)


func _snap(name: String) -> void:
	print("foto ", name, " erro=", root.get_texture().get_image().save_png("%s/%s.png" % [_out, name]))


func _process(delta: float) -> bool:
	_time += delta
	var cam: Camera3D = _match.get_node("Main/Camera")
	if _step == 0 and _time >= 14.0:
		_snap("jogador")
		_step = 1
	elif _step >= 1 and _step <= 4 and _time >= 14.0 + 0.6 * _step:
		if _time < 14.0 + 0.6 * _step + 0.3:   # 1º instante: posiciona; 0,3 s depois: o quadro já saiu
			cam.set_process(false)
			var dir: Vector3 = (get_nodes_in_group("home_base")[_step - 1] as Node3D).global_position.normalized()
			cam.global_position = dir * 230.0
			cam.look_at(Vector3.ZERO, Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
		else:
			_snap("planeta_%d" % _step)
			_step += 1
	elif _step > 4:
		quit(0)
		return true
	return false
