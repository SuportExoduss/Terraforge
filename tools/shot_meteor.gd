extends SceneTree
## Fotografa o meteoro: sombra no chão, rocha caindo e cratera. Exige janela.
## Uso: godot_console --path . -s res://tools/shot_meteor.gd -- <pasta de saída>

var _match: Node
var _out := ""
var _cam: Camera3D


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	var meteors: Node3D = _match.get_node("Meteors")
	meteors.min_seconds_between = 1.0
	meteors.max_seconds_between = 1.0
	meteors.quiet_after_start_seconds = 0.5
	meteors.warning_seconds = 4.0
	meteors.rock_fall_seconds = 2.0
	meteors.scar_seconds = 20.0
	root.add_child(_match)
	_run()


func _snap(name: String) -> void:
	await create_timer(0.4).timeout   # a imagem lida é a do quadro anterior
	print("foto ", name, " erro=", root.get_texture().get_image().save_png("%s/%s.png" % [_out, name]))


func _look(meteors: Node3D, height: float) -> void:
	var up: Vector3 = meteors._impact_direction
	var side := up.cross(Vector3.UP).normalized()
	_cam.global_position = meteors._impact_point + up * height + side * height * 0.6
	_cam.look_at(meteors._impact_point + up * 4.0, up)


func _run() -> void:
	var bus := root.get_node("EventBus")
	await bus.match_started
	var meteors: Node3D = _match.get_node("Meteors")
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 2000.0
	_match.add_child(_cam)
	_cam.make_current()
	await bus.global_event_warning
	await create_timer(1.8).timeout   # sombra já grande, rocha ainda no céu
	_look(meteors, 45.0)
	await _snap("meteoro_aviso")
	await create_timer(1.2).timeout   # rocha despencando
	_look(meteors, 60.0)
	await _snap("meteoro_queda")
	await bus.radial_damage
	await create_timer(0.3).timeout
	_look(meteors, 55.0)
	await _snap("meteoro_cratera")
	quit(0)
