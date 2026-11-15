extends SceneTree
## Fotografa o menu (com o aviso de missões) e a tela de MISSÕES — exige janela, sem --headless. Usa um perfil de teste
## (nunca o de verdade): sequência de 3 dias, 1ª missão pronta, 2ª pela metade e 3ª já resgatada.
## Uso: godot_console --path . --resolution 960x540 -s res://tools/shot_missions.gd -- <pasta de saída>

const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const TEST_PROFILE := "user://profile_shot_missions.json"

var _out := ""
var _frame := 0
var _menu: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	await process_frame
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()
	profile.data["matches"] = 5   # não é a primeira partida
	var today := DailyMissions.todays()
	profile.data["streak"] = {"count": 3, "last_day": DailyMissions.today() - 1}
	DailyMissions.state()["progress"][today[0][0]] = int(today[0][3])
	DailyMissions.state()["progress"][today[1][0]] = int(today[1][3]) / 2
	DailyMissions.state()["progress"][today[2][0]] = int(today[2][3])
	DailyMissions.state()["claimed"].append(today[2][0])
	profile.save()   # o menu recarrega o perfil do arquivo
	_menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(_menu)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 40:
		root.get_texture().get_image().save_png("%s/missions_menu.png" % _out)
		_menu.get_node("Box/Dock/Missions").pressed.emit()
	if _frame == 60:
		root.get_texture().get_image().save_png("%s/missions_screen.png" % _out)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(0)
	return false
