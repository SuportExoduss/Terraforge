extends SceneTree
## Foto dos CONTROLES (Passo 156) — exige janela. Modo "hud": partida com botões no tamanho <btn_size 0..1> (0 = 60%, 0.5 = 100%, 1 = 140%),
## sprint recarregando e habilidade pronta; modo "panel": painel de Ajustes com o controle de tamanho e as teclas.
## Uso: godot_console --path . --resolution 844x390 -s res://tools/shot_controls.gd -- <arquivo.png> <hud|panel> [btn_size]

var _out := ""
var _mode := "hud"
var _time := 0.0
var _ready_to_shoot := false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_mode = args[1] if args.size() > 1 else "hud"
	var profile: Object = load("res://scripts/core/profile.gd")
	profile.path = "user://profile_shot_controls.json"   # perfil descartável: não mexe no jogo de verdade
	profile.data = profile.defaults()
	profile.data["matches"] = 20   # fora do treino: sem dicas por cima
	profile.save()
	var settings = load("res://scripts/core/settings.gd")
	if args.size() > 2:
		settings.set_value("btn_size", float(args[2]))
	if _mode == "panel":
		var panel = load("res://scripts/ui/settings_panel.gd").new()
		root.add_child(panel)
	else:
		var match_scene: Node = load("res://scenes/match.tscn").instantiate()
		match_scene.get_node("MatchSetup").skip_ceremony = true
		root.add_child(match_scene)
	_ready_to_shoot = true


func _process(delta: float) -> bool:
	if not _ready_to_shoot:
		return false
	var before := _time
	_time += delta
	if _mode == "hud" and before < 4.0 and _time >= 4.0:
		root.get_node("EventBus").sprint_used.emit(1, 3.5)
	var wait := 14.0 if _mode == "hud" else 1.5
	if _mode == "hud" and before < 5.0 and _time >= 5.0:
		print("foto erro=", root.get_texture().get_image().save_png(_out))
		quit(0)
		return true
	if _mode == "panel" and _time >= wait:
		print("foto erro=", root.get_texture().get_image().save_png(_out))
		quit(0)
		return true
	return false
