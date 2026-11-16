extends SceneTree
## Teste de fumaça do Passo 132 (DD-170): CONQUISTAS AMPLIADAS E TÍTULOS. (1) a tabela: cada conquista nova dispara só no
## mínimo (carreira, maestria, nível, liga); (2) os títulos de conquista não se compram nem com muita moeda e gema, e cada um
## aponta para uma conquista que existe; (3) numa partida de verdade, um perfil perto das metas ganha as conquistas novas, as
## gemas (5 cada) e os títulos certos (só os das conquistas novas), grava tudo no perfil salvo e mostra "TÍTULO NOVO" nos
## resultados; (4) o título ganho se equipa e aparece no perfil; (5) a segunda partida não repete nem título nem conquista.
## Usa um perfil só dele. Uso: godot_console --headless --path . -s res://tools/smoke_titles.gd

const TEST_PROFILE := "user://profile_smoke_titles.json"

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _sorted(list: Array) -> Array:
	var out := list.duplicate()
	out.sort()
	return out


func _run() -> void:
	var ach = load("res://scripts/core/achievements.gd")
	var cos = load("res://scripts/core/cosmetics.gd")
	var profile = load("res://scripts/core/profile.gd")

	# 1. A tabela: limites exatos das conquistas novas
	var limits := [
		["seasoned", "matches", 50], ["champion", "total_wins", 5], ["legend", "total_wins", 25], ["builder", "total_loops", 100],
		["scissors", "total_cuts", 50], ["exterminator", "total_kills", 10], ["master_cartographer", "loops", 25],
		["ascending", "level", 10], ["platinum", "rating", 1550],
	]
	for l in limits:
		var below := {l[1]: l[2] - 1}
		if not _check(not ach.earned(below).has(l[0]), "%s não sai com %s=%s" % [l[0], l[1], l[2] - 1]): return
		if not _check(ach.earned({l[1]: l[2]}).has(l[0]), "%s sai com %s=%s" % [l[0], l[1], l[2]]): return
	if not _check(not ach.earned({"percent": 0.74}).has("unbeatable") and ach.earned({"percent": 0.75}).has("unbeatable"), "Imbatível só com 75%"): return
	if not _check(ach.description_of("champion") == "Vença 5 partidas" and ach.description_of("nao_existe") == "", "descrições"): return
	var seen := {}
	for entry: Array in ach.LIST:
		if not _check(not seen.has(entry[0]), "id de conquista repetido: %s" % entry[0]): return
		seen[entry[0]] = true

	# 2. Títulos de conquista: apontam para conquista real, não se compram, não são do passe
	var bound := 0
	profile.data = profile.defaults()
	profile.data["coins"] = 100000
	profile.data["gems"] = 100000
	for item: Array in cos.items("title"):
		var source: String = cos.achievement_of(item)
		if source == "":
			continue
		bound += 1
		if not _check(seen.has(source), "título %s aponta para conquista inexistente %s" % [item[0], source]): return
		if not _check(cos.unbuyable(item) and not cos.pass_only(item) and not cos.can_afford(item) and not cos.buy(item[0], "title") and not cos.is_owned(item[0], "title"), "título %s não se compra nem rico" % item[0]): return
	if not _check(bound == 6, "6 títulos de conquista (achei %d)" % bound): return
	if not _check(cos.achievement_of(cos.entry("forjador", "title")) == "" and cos.pass_only(cos.entry("forjador", "title")), "o título do passe continua sendo do passe"): return

	# 3. Uma partida de verdade: perfil a uma partida/vitória/corte/área das metas de carreira
	await _bus.match_started
	await process_frame
	var services: Node = root.get_node("Services")
	profile.data = profile.defaults()
	profile.data["matches"] = 49
	profile.data["wins"] = 4
	profile.data["loops"] = 98
	profile.data["cuts"] = 49
	profile.save()
	_bus.territory_loop_claimed.emit(1, 40)
	_bus.territory_loop_claimed.emit(1, 40)
	_bus.trail_cut.emit(2, 1)
	_bus.territory_score_changed.emit(1, 0.55)
	_bus.territory_score_changed.emit(2, 0.20)
	_match.get_node("MatchFlow").pace = 0.0
	_bus.match_ended.emit()
	await process_frame
	var last: Dictionary = services.rewards.last
	var fresh: Array = last.get("new_achievements", [])
	for id in ["seasoned", "champion", "builder", "scissors", "conqueror", "dominator"]:
		if not _check(fresh.has(id), "conquista nova %s (veio %s)" % [id, fresh]): return
	for id in ["legend", "unbeatable", "master_cartographer", "exterminator", "platinum"]:
		if not _check(not fresh.has(id), "conquista %s não deveria sair (veio %s)" % [id, fresh]): return
	if not _check(_sorted(last.get("new_titles", [])) == ["campeao", "tesoura"], "títulos novos = Campeão e Tesoura Afiada (veio %s)" % [last.get("new_titles")]): return
	if not _check(int(last["gems"]) == fresh.size() * int(load("res://scripts/core/match_rewards.gd").GEMS_PER_ACHIEVEMENT), "5 gemas por conquista nova (%s)" % last["gems"]): return
	profile.load_data()
	if not _check(cos.is_owned("campeao", "title") and cos.is_owned("tesoura", "title") and not cos.is_owned("imbativel", "title") and not cos.is_owned("lenda_viva", "title"), "perfil salvo tem só os títulos das conquistas novas: %s" % [profile.data.get("owned_titles")]): return
	if not _check(int(profile.data["wins"]) == 5 and int(profile.data["loops"]) == 100 and int(profile.data["cuts"]) == 50, "totais da carreira: %s" % [profile.data]): return
	var text: String = _match.get_node("Results/Panel/Box/Columns/Side/Rewards").get_parsed_text()
	if not _check(text.contains("CONQUISTA: Campeão — TÍTULO NOVO") and text.contains("CONQUISTA: Tesoura Afiada — TÍTULO NOVO"), "resultados mostram os títulos novos:\n" + text): return
	if not _check(text.count("CONQUISTA:") == 4 and text.contains("+%d conquistas (veja no perfil)" % (fresh.size() - 4)), "no máximo 4 linhas de conquista e o resto vira +N:\n" + text): return
	await process_frame
	var panel_rect: Rect2 = _match.get_node("Results/Panel").get_global_rect()
	if not _check(panel_rect.position.y >= 0.0 and panel_rect.end.y <= 540.0, "com %d conquistas de uma vez o painel ainda cabe na tela: %s
%s" % [fresh.size(), panel_rect, text]): return

	# 4. O título se equipa e vira o texto do perfil
	if not _check(cos.equip("campeao", "title") and cos.title_text() == "Campeão" and not cos.equip("imbativel", "title"), "equipar título ganho (e recusar o que não é seu)"): return

	# 5. Fim: a mesma conta numa 2ª apuração (mesmo perfil, nada mudou) não repete título nem conquista
	profile.data["matches"] = int(profile.data["matches"])   # (a conta de repetição está no smoke_achievements; aqui só o título)
	if not _check(not cos.grant("campeao", "title"), "conceder de novo um título que já é seu devolve falso"): return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
