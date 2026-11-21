extends SceneTree
## Foto dos CONTROLES DE PC (Passo 157) — exige janela. Modo "prompt": pergunta A/D ou setas; "hud": partida com mapa aberto.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_pc_controls.gd -- <arquivo.png> <prompt|hud|map>

var _out := ""
var _mode := "prompt"
var _time := 0.0
var _go := false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_mode = args[1] if args.size() > 1 else "prompt"
	var profile: Object = load("res://scripts/core/profile.gd")
	profile.path = "user://profile_shot_pc_controls.json"   # perfil descartável
	profile.data = profile.defaults()
	profile.data["matches"] = 20
	profile.save()
	if _mode == "prompt":
		root.add_child(load("res://scripts/ui/scheme_prompt.gd").new())
	else:
		var match_scene: Node = load("res://scenes/match.tscn").instantiate()
		match_scene.get_node("MatchSetup").skip_ceremony = true
		root.add_child(match_scene)
	_go = true


func _process(delta: float) -> bool:
	if not _go:
		return false
	var before := _time
	_time += delta
	if _mode == "map" and before < 3.0 and _time >= 3.0:
		var ev := InputEventKey.new()
		ev.keycode = KEY_M
		ev.pressed = true
		root.push_input(ev)
	var wait := 1.0 if _mode == "prompt" else 5.0
	if _time >= wait:
		print("foto erro=", root.get_texture().get_image().save_png(_out))
		quit(0)
		return true
	return false
