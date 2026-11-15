extends SceneTree
## Fotografa a HUD da partida (cartões de vidro, Passo 111) no tamanho de texto pedido — exige janela.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_hud.gd -- <pasta de saída> <texto 0..1>

var _match: Node
var _out := ""
var _time := 0.0
var _text := 0.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # autoloads prontos
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_text = float(args[1]) if args.size() > 1 else 0.0
	load("res://scripts/core/profile.gd").data["settings"] = {"text": _text}   # só na memória
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	root.add_child(_match)


func _process(delta: float) -> bool:
	if _match == null:
		return false
	_time += delta
	if _time >= 8.0:
		print("foto erro=", root.get_texture().get_image().save_png("%s/hud_texto%d.png" % [_out, int(_text * 100.0)]))
		quit(0)
		return true
	return false
