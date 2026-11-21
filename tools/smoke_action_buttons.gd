extends SceneTree
## Teste de fumaça do Passo 155 (DD-194): BOTÕES DE AÇÃO com cara de jogo. (1) ActionButton sozinho: pronto = letra e nome; recarregando = apagado,
## segundos no meio (sprint com decimal, habilidade inteira), nome some e o anel enche (progress); ao ficar pronto volta a letra; set_look troca
## cor/nome/letra sem perder a recarga; (2) na partida: o SPRINT nasce com a cor e o nome dele, a habilidade ganha a COR e o NOME do bioma do
## jogador (um por bioma no catálogo), e o relógio do sprint/habilidade chega ao botão (apaga, segundos, anel).
## Uso: godot_console --headless --path . -s res://tools/smoke_action_buttons.gd

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
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
		quit(1)
	return ok


func _run() -> void:
	# carrega aqui (não no topo): no modo -s o script compila antes dos autoloads e ActionButton -> Settings -> AudioDirector precisa do EventBus
	var ActionButtonScript = load("res://scripts/ui/action_button.gd")
	# 1. ActionButton sozinho
	var btn = ActionButtonScript.new(Color(0.9, 0.3, 0.2), "TESTE", "T", true)
	if not _check(not btn.disabled and btn.text == "T" and btn.progress() == 1.0, "nasce pronto, com a letra"): return
	btn.charge(3.5, 3.5)
	if not _check(btn.disabled and btn.text == "3.5" and is_equal_approx(btn.progress(), 0.0), "recarga cheia: apagado, 3.5, anel vazio (%s)" % btn.text): return
	btn.charge(1.75, 3.5)
	if not _check(btn.text == "1.8" or btn.text == "1.7", "sprint mostra decimal (%s)" % btn.text): return
	if not _check(is_equal_approx(btn.progress(), 0.5), "metade da recarga = anel pela metade (%f)" % btn.progress()): return
	if not _check(not btn.get_node("Caption").visible, "recarregando o nome some (o número ocupa o botão)"): return
	btn.set_look(Color(0.1, 0.8, 0.4), "OUTRO", "O")
	if not _check(btn.disabled and (btn.text == "1.8" or btn.text == "1.7"), "set_look não perde a recarga em andamento (%s)" % btn.text): return
	btn.charge(0.0, 3.5)
	if not _check(not btn.disabled and btn.text == "O" and btn.get_node("Caption").visible and btn.get_node("Caption").text == "OUTRO" and btn.progress() == 1.0, "pronto: letra nova e nome embaixo"): return
	btn.charge(-2.0, 0.0)   # número ruim não quebra (sem divisão por zero)
	if not _check(btn.progress() == 1.0 and not btn.disabled, "recarga negativa vira pronto"): return
	var whole = ActionButtonScript.new(Color.WHITE, "H", "H", false)
	whole.charge(7.2, 15.0)
	if not _check(whole.text == "8", "habilidade mostra inteiro arredondado para cima (%s)" % whole.text): return
	if not _check(btn.focus_mode == Control.FOCUS_NONE, "sem foco: ESPAÇO/ENTER não aciona"): return
	btn.free()
	whole.free()

	# 2. Na partida
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	await _bus.match_started
	await process_frame
	await process_frame
	var hud: Node = _match.get_node("Hud")
	var sprint = hud.find_child("SprintButton", true, false)
	var ability = hud.find_child("AbilityButton", true, false)
	if not _check(sprint != null and ability != null, "a HUD tem os dois botões de ação"): return
	if not _check(sprint.get_node("Caption").text == "SPRINT" and sprint.accent == UiTheme.INK and not sprint.disabled, "SPRINT: nome e cor próprios, pronto"): return
	var catalog = load("res://scripts/core/civilization_catalog.gd")
	var mine: Dictionary = catalog.ability_of(catalog.biome_of(1))
	if not _check(ability.visible and ability.accent == mine["color"] and ability.get_node("Caption").text == str(mine["name"]).to_upper() and ability.icon_text == mine["icon"], "habilidade: cor, nome e letra do bioma do jogador (%s)" % mine["id"]): return
	if not _check(ability.disabled and ability.text.is_valid_int() and ability.progress() < 0.1, "na largada a habilidade carrega: segundos no meio e anel quase vazio (%s %f)" % [ability.text, ability.progress()]): return
	_bus.sprint_used.emit(1, 3.5)
	if not _check(sprint.disabled and sprint.text == "3.5" and is_equal_approx(sprint.progress(), 0.0), "sprint usado: apaga com 3.5 e anel vazio (%s)" % sprint.text): return
	_bus.sprint_used.emit(2, 3.5)   # de outro corredor: não mexe no botão do jogador (já está apagado; confere que o texto não pulou)
	if not _check(sprint.text == "3.5", "sprint de outro corredor não mexe no meu botão"): return
	for i in range(1, 7):   # cada bioma tem cor própria e legível
		var a: Dictionary = catalog.ability_of(i)
		if not _check(a.has("color") and a["color"] is Color and a["color"].v > 0.6, "habilidade do bioma %d tem cor clara o bastante" % i): return
	var colors := {}
	for i in range(1, 7):
		colors[catalog.ability_of(i)["color"]] = true
	if not _check(colors.size() == 6, "6 habilidades, 6 cores diferentes"): return
	print("OK: botões de ação — anel de recarga, segundos (sprint decimal, habilidade inteira), cor e nome por habilidade, set_look sem perder a carga")
	quit(0)
