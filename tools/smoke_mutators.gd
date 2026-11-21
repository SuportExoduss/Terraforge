extends SceneTree
## Teste de fumaça do Passo 154 (DD-193): MUTADOR DO DIA. (1) o catálogo tem 6 regras únicas e gira pelo número do dia (igual para todos);
## (2) partida com `Services.mutator` = "relampago" e um planeta de 240 s nasce com 144 s (o relógio já tinha nascido: a ordem dos _ready
## importa) e mostra a faixa "MUTADOR: RELÂMPAGO"; as recargas continuam clássicas (3,5 s / 15 s); (3) cada uma das 6 regras muda
## SÓ os números que promete (o resto fica igual); (4) o menu mostra o cartão do mutador de hoje e o treino (1ª partida) é clássico.
## Uso: godot_console --headless --path . -s res://tools/smoke_mutators.gd

const Mutators := preload("res://scripts/core/mutators.gd")
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const SKILL_PROPS := ["sprint_cooldown", "ability_cooldown", "sprint_seconds", "lasso_seconds", "emp_seconds", "trick_seconds", "frost_seconds", "cannon_push"]
const METEOR_PROPS := ["min_seconds_between", "max_seconds_between"]

var _match: Node
var _bus: Node
var _services: Node
var _time := 0.0


func _initialize() -> void:
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 90.0:
		_fail("tempo esgotado")
	return false


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DailyMissions.day_override = -1
	quit(1)


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_fail(msg)
	return ok


# Foto dos números que os mutadores mexem; a chave é "Nó.propriedade".
func _snap() -> Dictionary:
	var s := {}
	for p: String in SKILL_PROPS:
		s["Skills." + p] = _match.get_node("Skills").get(p)
	for p: String in METEOR_PROPS:
		s["Meteors." + p] = _match.get_node("Meteors").get(p)
	s["MatchTimer.duration_seconds"] = _match.get_node("MatchTimer").duration_seconds
	return s


func _restore(s: Dictionary) -> void:
	for key: String in s:
		var parts := key.split(".")
		_match.get_node(parts[0]).set(parts[1], s[key])
	_match.get_node("MatchTimer").restore_seconds(int(s["MatchTimer.duration_seconds"]))


# Aplica o mutador e confere: cada número = antes x fator (1 se a regra não o cita).
func _expect(id: String, factors: Dictionary) -> bool:
	var before := _snap()
	Mutators.apply(id, _match)
	var after := _snap()
	for key: String in before:
		var want: float = before[key] * float(factors.get(key, 1.0))
		if not _check(is_equal_approx(after[key], want), "%s: %s deveria ir de %s para %s e foi para %s" % [id, key, before[key], want, after[key]]):
			return false
	_restore(before)
	return true


func _run() -> void:
	# a. Catálogo e rotação
	var ids := {}
	for m: Dictionary in Mutators.CATALOG:
		ids[m["id"]] = true
		if not _check(str(m["name"]) != "" and str(m["blurb"]) != "", "mutador %s sem nome ou texto" % m["id"]): return
	if not _check(Mutators.CATALOG.size() == 6 and ids.size() == 6, "6 mutadores com ids únicos"): return
	var week := {}
	for d in 6:
		week[Mutators.id_for_day(d)] = true
	if not _check(week.size() == 6 and Mutators.id_for_day(6) == Mutators.id_for_day(0) and Mutators.id_for_day(-1) == Mutators.id_for_day(5), "6 dias seguidos = 6 mutadores diferentes, depois repete"): return
	DailyMissions.day_override = 7
	if not _check(Mutators.today_id() == Mutators.id_for_day(7), "o mutador de hoje segue o número do dia"): return
	DailyMissions.day_override = -1
	if not _check(Mutators.banner("turbo") == "MUTADOR: TUDO TURBO" and Mutators.menu_line("turbo").begins_with("MUTADOR DE HOJE: TUDO TURBO\n"), "texto do menu e da faixa"): return
	if not _check(Mutators.banner("nada") == "" and Mutators.menu_line("") == "" and Mutators.by_id("nada").is_empty(), "id desconhecido não tem texto"): return

	# b. Partida de verdade: o mutador chega (inclusive ao relógio) e a faixa aparece
	_services = root.get_node("Services")
	_services.match_def = load("res://scripts/core/planet_def.gd").by_id("pequeno")   # 240 s
	_services.mutator = "relampago"
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	await _bus.match_started
	await process_frame
	var left: int = _match.get_node("MatchTimer").seconds_left()
	if not _check(left >= 143 and left <= 144, "relâmpago: 240 s viram 144 s (veio %d)" % left): return
	var banner: String = _match.find_child("EventLabel", true, false).text
	if not _check(banner == "MUTADOR: RELÂMPAGO", "faixa do HUD: %s" % banner): return
	var skills: Node = _match.get_node("Skills")
	if not _check(is_equal_approx(skills.sprint_cooldown, 3.5) and is_equal_approx(skills.ability_cooldown, 15.0), "o relâmpago não mexe nas recargas"): return

	# c. As 6 regras, uma a uma
	if not _expect("turbo", {"Skills.sprint_cooldown": 0.5, "Skills.ability_cooldown": 0.5}): return
	if not _expect("chuva", {"Meteors.min_seconds_between": 0.4, "Meteors.max_seconds_between": 0.4}): return
	if not _expect("relampago", {"MatchTimer.duration_seconds": 0.6}): return
	if not _expect("forte", {"Skills.lasso_seconds": 1.5, "Skills.emp_seconds": 1.5, "Skills.trick_seconds": 1.5, "Skills.frost_seconds": 1.5, "Skills.cannon_push": 1.5}): return
	if not _expect("arrancada", {"Skills.sprint_seconds": 1.5}): return
	if not _expect("ceu", {"Meteors.min_seconds_between": 2.0, "Meteors.max_seconds_between": 2.0}): return

	# d. Menu: o cartão mostra o mutador de hoje; a 1ª partida (treino) é clássica
	_match.queue_free()
	await process_frame
	Profile.path = "user://profile_smoke_mutators.json"
	Profile.data = Profile.defaults()
	Profile.data["matches"] = 1
	Profile.save()
	DailyMissions.day_override = 8
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var today := Mutators.id_for_day(8)
	if not _check(_services.mutator == today and menu.get_node("Mutator").visible and menu.get_node("Mutator/Text").text == Mutators.menu_line(today), "menu: cartão com o mutador do dia (%s)" % _services.mutator): return
	menu.queue_free()
	await process_frame
	Profile.data["matches"] = 0
	Profile.save()
	menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	if not _check(_services.mutator == "" and not menu.get_node("Mutator").visible, "menu: o treino não tem mutador"): return
	DailyMissions.day_override = -1
	print("OK")
	quit(0)
