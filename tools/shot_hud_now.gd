extends SceneTree
## Foto da HUD da partida COM as mecânicas novas (sprint, habilidade, mutador, minimapa) — exige janela.
## Duas fotos: <arquivo>_recarga.png (sprint e habilidade recarregando, aos 5 s) e <arquivo>.png (tudo pronto, aos 14 s).
## Uso: godot_console --path . --resolution 844x390 -s res://tools/shot_hud_now.gd -- <arquivo.png>

var _match: Node
var _out := ""
var _time := 0.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_out = OS.get_cmdline_user_args()[0]
	var profile: Object = load("res://scripts/core/profile.gd")
	profile.path = "user://profile_shot_hud_now.json"
	profile.data = profile.defaults()
	profile.data["matches"] = 20   # fora do treino: sem dicas de tutorial por cima
	profile.save()
	root.get_node("Services").mutator = "turbo"
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	root.add_child(_match)


func _process(delta: float) -> bool:
	if _match == null:
		return false
	var before := _time
	_time += delta
	if before < 4.0 and _time >= 4.0:
		root.get_node("EventBus").sprint_used.emit(1, 3.5)   # sprint recarregando na 1ª foto
	if before < 5.0 and _time >= 5.0:
		print("foto recarregando erro=", root.get_texture().get_image().save_png(_out.replace(".png", "_recarga.png")))
	if _time >= 14.0:
		print("foto pronto erro=", root.get_texture().get_image().save_png(_out))
		quit(0)
		return true
	return false
