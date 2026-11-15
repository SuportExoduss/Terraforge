extends SceneTree
## Passo 124: fotografa um planeta temático (câmera do jogador + o planeta visto de cima de 2 bases) para conferir o shader do bioma.
## Exige janela. Uso: godot_console --path . -s res://tools/shot_biome.gd -- <pasta de saída> <id do planeta: gelo|vulcao|...>

var _match: Node
var _out := ""
var _radius := 100.0
var _time := 0.0
var _step := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var def: PlanetDef = PlanetDef.by_id(args[1])
	_radius = def.radius
	root.get_node("Services").match_def = def
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	root.add_child(_match)


func _snap(shot: String) -> void:
	print("foto ", shot, " erro=", root.get_texture().get_image().save_png("%s/%s.png" % [_out, shot]))


func _process(delta: float) -> bool:
	_time += delta
	var cam: Camera3D = _match.get_node("Main/Camera")
	if _step == 0 and _time >= 14.0:
		_snap("jogador")
		_step = 1
	elif _step >= 1 and _step <= 2 and _time >= 14.0 + 0.6 * _step:
		if _time < 14.0 + 0.6 * _step + 0.3:
			cam.set_process(false)
			var dir: Vector3 = (get_nodes_in_group("home_base")[_step - 1] as Node3D).global_position.normalized()
			cam.global_position = dir * _radius * 2.3
			cam.look_at(Vector3.ZERO, Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
		else:
			_snap("planeta_%d" % _step)
			_step += 1
	elif _step > 2:
		quit(0)
		return true
	return false
