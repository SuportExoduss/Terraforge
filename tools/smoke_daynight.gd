extends SceneTree
## Teste de fumaça do Passo 31 (ciclo dia/noite, CL-001/CL-006): (1) a fase 0 é o visual de sempre (nada muda para quem
## joga os primeiros minutos); (2) o dia vira pôr do sol (quente) e noite (fria e mais escura) sem nunca passar dos pisos
## de luz, e sem saltos bruscos entre um segundo e outro; (3) o relógio da partida move o Sol e o ambiente de verdade
## (a fase é função só dos segundos restantes); (4) o recurso de ambiente da cena não é alterado (compartilhado).
## Uso: godot_console --headless --path . -s res://tools/smoke_daynight.gd

var _match: Node
var _bus: Node
var _cycle: Node
var _director: Script
var _failed := false


func _initialize() -> void:
	_director = load("res://scripts/world/day_night_cycle.gd")
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_cycle = _match.get_node("DayNight")
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 and absf(a.b - b.b) < 0.001


func _run() -> void:
	var sun: DirectionalLight3D = _match.get_node("Main/Sun")

	# 1. Fase 0 = visual de antes (valores de main.tscn)
	var day: Dictionary = _director.sample(0.0)
	_check(is_equal_approx(day["sun_energy"], 1.2), "dia: energia do Sol %s" % day["sun_energy"])
	_check(is_equal_approx(day["ambient_energy"], 0.6), "dia: luz ambiente %s" % day["ambient_energy"])
	_check(_close(day["ambient_color"], Color(0.7, 0.75, 0.85)), "dia: cor ambiente mudou")
	_check(_close(day["background"], Color(0.04, 0.06, 0.13)), "dia: cor do fundo mudou")
	_check(_close(day["sun_color"], Color.WHITE), "dia: o Sol é branco")

	# 2. Pôr do sol quente, noite fria e mais escura; pisos e transições graduais
	var sunset: Dictionary = _director.sample(0.6)
	var night: Dictionary = _director.sample(1.0)
	_check(sunset["sun_color"].r > sunset["sun_color"].b + 0.3, "pôr do sol deve ser quente (vermelho > azul)")
	_check(night["sun_color"].b > night["sun_color"].r + 0.3, "noite deve ser fria (azul > vermelho)")
	_check(night["sun_energy"] < sunset["sun_energy"] and sunset["sun_energy"] < day["sun_energy"], "o Sol deve enfraquecer do dia à noite")
	var previous: Dictionary = day
	for i in range(0, 101):
		var light: Dictionary = _director.sample(i / 100.0)
		_check(light["ambient_energy"] >= _director.AMBIENT_FLOOR - 0.0001, "fase %d%%: luz ambiente abaixo do piso" % i)
		_check(light["sun_energy"] >= _director.SUN_FLOOR - 0.0001, "fase %d%%: Sol abaixo do piso" % i)
		_check(absf(light["sun_energy"] - previous["sun_energy"]) < 0.03, "fase %d%%: salto no Sol (%.3f)" % [i, absf(light["sun_energy"] - previous["sun_energy"])])
		_check(absf(light["ambient_energy"] - previous["ambient_energy"]) < 0.03, "fase %d%%: salto no ambiente" % i)
		for channel in ["r", "g", "b"]:
			_check(absf(light["sun_color"][channel] - previous["sun_color"][channel]) < 0.04, "fase %d%%: salto na cor do Sol (%s)" % [i, channel])
			_check(absf(light["ambient_color"][channel] - previous["ambient_color"][channel]) < 0.03, "fase %d%%: salto na cor ambiente (%s)" % [i, channel])
		previous = light
	_check(_director.sample(-5.0)["sun_energy"] == day["sun_energy"] and _director.sample(9.0)["sun_energy"] == night["sun_energy"], "fases fora de 0..1 devem ser limitadas")

	# 3. O relógio da partida move a luz (cada emissão é conferida na hora: o relógio real também emite a cada segundo)
	await _bus.match_started
	var env: Environment = _match.get_node("Main/WorldEnvironment").environment   # só depois do _ready: o ciclo troca o recurso por uma cópia
	var duration: float = _match.get_node("MatchTimer").duration_seconds
	for seconds_left in [int(duration), int(duration * 0.5), int(duration * 0.3), 0]:
		_bus.match_clock_changed.emit(seconds_left)
		var expected: Dictionary = _director.sample(1.0 - seconds_left / duration)
		_check(is_equal_approx(_cycle.phase, 1.0 - seconds_left / duration), "faltando %d s: fase %.3f" % [seconds_left, _cycle.phase])
		_check(is_equal_approx(sun.light_energy, expected["sun_energy"]), "faltando %d s: o Sol não acompanhou" % seconds_left)
		_check(_close(sun.light_color, expected["sun_color"]), "faltando %d s: cor do Sol não acompanhou" % seconds_left)
		_check(is_equal_approx(env.ambient_light_energy, expected["ambient_energy"]), "faltando %d s: ambiente não acompanhou" % seconds_left)
		_check(_close(env.background_color, expected["background"]), "faltando %d s: fundo não acompanhou" % seconds_left)
	_check(sun.light_energy < 1.0 and env.ambient_light_energy < 0.5, "no fim da partida é noite")

	# 4. O recurso de ambiente da cena (compartilhado entre partidas) continua intacto
	var fresh: Node = load("res://scenes/main.tscn").instantiate()
	var fresh_env: Environment = fresh.get_node("WorldEnvironment").environment
	_check(is_equal_approx(fresh_env.ambient_light_energy, 0.6), "o recurso Environment da cena foi alterado (%.2f)" % fresh_env.ambient_light_energy)
	fresh.free()

	if not _failed:
		print("OK")
		quit(0)
