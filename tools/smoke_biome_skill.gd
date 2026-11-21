extends SceneTree
## Teste de fumaça do Passo 147 (DD-183): HABILIDADE ESPECIAL do bioma. (1) a 1ª carga só fica pronta 15 s depois da largada e o
## ability_charging sai para todo corredor; (2) cada corredor tem a habilidade do SEU bioma (diferentes entre si; trocar o bioma
## escolhido troca a do jogador); (3) E (sem eco) e o botão da HUD pedem a habilidade; (4) sem alvo (Laço/EMP/Canhonada) ou sem vida
## faltando (Cura) NÃO gasta a carga; (5) cada efeito: Laço (só o rival mais próximo, ×0,5), EMP (rivais ≤ 18, ×0,6), Cura (+4),
## Manobra (curva ×1,6), Canhonada (empurra os rivais ≤ 16 para longe), Armadura de Gelo (escudo); (6) efeito de tempo acaba sozinho,
## renovar não soma e fim de partida desfaz; (7) fora de campo não gasta; (8) bot usa por regra (Cura só ferido, Armadura só com rival
## por perto, ofensiva só com alvo); (9) botão da HUD aparece, apaga com os segundos e volta pronto; (10) a tela de civilizações
## mostra a habilidade de cada bioma.
## Uso: godot_console --headless --path . -s res://tools/smoke_biome_skill.gd

var _match: Node
var _bus: Node
var _planet: Node
var _time := 0.0
var _used: Array = []       # ability_used(id, habilidade)
var _charging: Array = []   # ability_charging(id, recarga, habilidade), desde a largada


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 3
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.ability_used.connect(func(id, kind): _used.append([id, kind]))
	_bus.ability_charging.connect(func(id, cd, kind): _charging.append([id, cd, kind]))
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


func _key(code: Key, echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	return ev


## Espera tempo de jogo (o quadro dura o que o computador levar).
func _wait(seconds: float) -> void:
	var end := _time + seconds
	while _time < end:
		await process_frame


## Põe `r` a `d` unidades de `p` (ao lado dele, no chão).
func _near(r: Node3D, p: Node3D, d: float) -> void:
	r.teleport_to(p.global_position + p.global_basis.x * d)


## Põe `r` do outro lado do planeta (inclinado por `tilt`), bem longe de `p`.
func _far(r: Node3D, p: Node3D, tilt: float) -> void:
	var up: Vector3 = (p.global_position - _planet.center).normalized()
	r.teleport_to(_planet.center - up.rotated(p.global_basis.x, tilt) * 100.0)


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	_planet = root.get_node("Services").planet   # o planeta só existe depois da largada
	var skills: Node = _match.get_node("Skills")
	var catalog = load("res://scripts/core/civilization_catalog.gd")
	var runner: Node3D = _match.get_node("Main/Runner")
	var b: Node3D = _match.get_node("Main/Runner2")
	var c: Node3D = _match.get_node("Main/Runner3")
	var d: Node3D = _match.get_node("Main/Runner4")
	for r in [runner, b, c, d]:
		r.set_process(false)   # ninguém anda sozinho: o teste põe cada um no lugar
	skills.bots_sprint = false   # (também desliga as habilidades dos bots até a seção 8)
	var base: float = runner.move_speed
	var base_turn: float = runner.turn_speed_degrees
	var health: Node = runner.get_node("Health")
	var ids: Array = [1, b.get_node("Civilization").id, c.get_node("Civilization").id, d.get_node("Civilization").id]

	# 1. Largada: ninguém tem a carga; ability_charging(15 s) saiu para cada um
	if not _check(ids == [1, 2, 3, 4], "ids dos corredores (%s)" % [ids]): return
	for id in ids:
		if not _check(not skills.ability_ready(id) and skills.ability_cooldown_left(id) > 14.0, "carga da %d ainda não está pronta" % id): return
		var seen: Array = _charging.filter(func(e): return e[0] == id and absf(e[1] - 15.0) < 0.001)
		if not _check(seen.size() == 1 and seen[0][2] == skills.ability_kind(id), "ability_charging(%d, 15) emitido na largada" % id): return
	if not _check(not skills.use_ability(1) and _used.is_empty(), "antes dos 15 s a habilidade não dispara"): return

	# 2. Cada corredor tem a habilidade do seu bioma
	var kinds: Array = ids.map(func(id): return skills.ability_kind(id))
	var unique := {}
	for kind in kinds:
		unique[kind] = true
	if not _check(unique.size() == 4, "4 corredores, 4 habilidades diferentes (%s)" % [kinds]): return
	for id in ids:
		if not _check(skills.ability_kind(id) == catalog.ability_of(catalog.biome_of(id))["id"], "habilidade da %d = a do bioma dela" % id): return
	var ability_ids := {}
	for i in range(1, 7):
		ability_ids[catalog.ability_of(i)["id"]] = true
		if not _check(catalog.ability_named(catalog.ability_of(i)["id"]) == catalog.ability_of(i), "ability_named acha a do bioma %d" % i): return
	if not _check(ability_ids.size() == 6 and catalog.ability_named("nada").is_empty(), "6 habilidades, uma por bioma"): return

	# 3. E (sem eco) e o botão da HUD
	var button: Button = _match.get_node("Hud").find_child("AbilityButton", true, false)
	if not _check(button != null and button.visible and button.size.x >= 64.0 and button.size.y >= 64.0, "botão da habilidade na HUD, grande e visível"): return
	if not _check(button.disabled and button.text.is_valid_int() and int(button.text) >= 14, "carregando: botão apagado com os segundos (%s)" % button.text): return
	button.button_down.emit()
	var held: bool = TouchSteering.is_ui_pointer_held
	button.button_up.emit()
	if not _check(held and not TouchSteering.is_ui_pointer_held, "o toque no botão não vira direção"): return
	var sprint: Button = _match.get_node("Hud").find_child("SprintButton", true, false)
	if not _check(sprint != null and button.get_global_rect().end.x <= sprint.get_global_rect().position.x + 0.5, "o botão da habilidade fica à esquerda do SPRINT"): return
	skills.ability_cooldown = 0.5    # a partir daqui, cargas curtas
	skills.lasso_seconds = 0.4
	skills.emp_seconds = 0.4
	skills.trick_seconds = 0.4
	skills._ability_cd.erase(1)      # (a 1ª carga de 15 s já foi verificada)
	skills._kinds[1] = "trick"       # sem alvo: dá para testar o pedido sem posicionar ninguém
	skills._unhandled_input(_key(KEY_A))
	skills._unhandled_input(_key(KEY_E, true))
	if not _check(_used.is_empty(), "outra tecla e o eco do E não disparam"): return
	skills._unhandled_input(_key(KEY_E))
	if not _check(_used == [[1, "trick"]] and not skills.ability_ready(1), "E dispara e gasta a carga (%s)" % [_used]): return
	var again: Array = _charging.filter(func(e): return e[0] == 1 and absf(e[1] - 0.5) < 0.001)
	if not _check(again.size() == 1, "ability_charging(1, 0.5) depois do uso"): return
	if not _check(button.disabled and button.text == "1", "recarregando: o botão mostra os segundos (%s)" % button.text): return
	skills._unhandled_input(_key(KEY_E))
	if not _check(_used.size() == 1, "durante a recarga, E não faz nada"): return
	await _wait(0.7)
	if not _check(absf(runner.turn_speed_degrees - base_turn) < 0.001, "a Manobra acabou: curva volta (%.1f)" % runner.turn_speed_degrees): return
	if not _check(skills.ability_ready(1) and not button.disabled and button.text == catalog.ability_named("trick")["icon"], "carga volta e o botão volta pronto (%s)" % button.text): return
	_used.clear()
	button.pressed.emit()
	if not _check(_used == [[1, "trick"]], "tocar o botão pede a habilidade do jogador"): return
	await _wait(0.7)
	_used.clear()

	# 4. Sem alvo ou sem vida faltando: não gasta a carga (todos os rivais longe)
	_far(b, runner, 0.5)
	_far(c, runner, -0.5)
	_far(d, runner, 0.0)
	if not _check(runner.global_position.distance_to(b.global_position) > 100.0 and runner.global_position.distance_to(c.global_position) > 100.0, "pré-condição: rivais longe"): return
	for kind in ["lasso", "emp", "cannon", "heal"]:
		skills._kinds[1] = kind
		skills._ability_cd.erase(1)
		if not _check(not skills.use_ability(1) and skills.ability_ready(1) and _used.is_empty(), "%s sem alvo / vida cheia não gasta a carga" % kind): return

	# 5a. Laço: só o rival mais próximo, a metade da velocidade
	_near(b, runner, 10.0)
	_near(c, runner, 24.0)
	var base_b: float = b.move_speed
	var base_c: float = c.move_speed
	skills._kinds[1] = "lasso"
	skills._ability_cd.erase(1)
	if not _check(skills.use_ability(1) and _used == [[1, "lasso"]], "Laço com rival ao alcance dispara"): return
	if not _check(absf(b.move_speed - base_b * 0.5) < 0.001 and absf(c.move_speed - base_c) < 0.001, "Laço pega só o mais próximo (%.1f / %.1f)" % [b.move_speed, c.move_speed]): return
	if not _check(_match.get_node("Main").find_child("AbilityRing", true, false) != null, "o anel do efeito aparece"): return
	# renovar não soma
	skills._ability_cd.erase(1)
	skills.use_ability(1)
	if not _check(absf(b.move_speed - base_b * 0.5) < 0.001, "repetir o Laço só renova o tempo (%.1f)" % b.move_speed): return
	await _wait(0.7)
	if not _check(absf(b.move_speed - base_b) < 0.001 and skills._timed.is_empty(), "o Laço acabou: velocidade volta (%.1f)" % b.move_speed): return
	_used.clear()

	# 5b. Pulso EMP: rivais até 18 a ×0,6; o de 24 não é pego
	skills._kinds[1] = "emp"
	skills._ability_cd.erase(1)
	_near(d, runner, -12.0)
	var base_d: float = d.move_speed
	if not _check(skills.use_ability(1), "EMP com rivais por perto dispara"): return
	if not _check(absf(b.move_speed - base_b * 0.6) < 0.001 and absf(d.move_speed - base_d * 0.6) < 0.001 and absf(c.move_speed - base_c) < 0.001, "EMP pega os de dentro e deixa o de fora"): return
	await _wait(0.7)
	if not _check(absf(b.move_speed - base_b) < 0.001 and absf(d.move_speed - base_d) < 0.001, "o EMP acabou"): return
	_used.clear()

	# 5c. Cura: +4 pontos, só com vida faltando
	skills._kinds[1] = "heal"
	skills._ability_cd.erase(1)
	var max_points: int = health.max_points
	health.points = max_points - 8
	if not _check(skills.use_ability(1), "Cura com vida faltando dispara"): return
	if not _check(health.points >= max_points - 4 and health.points <= max_points, "a Cura devolveu 1 coração (%d de %d)" % [health.points, max_points]): return
	skills._ability_cd.erase(1)
	health.points = max_points
	if not _check(not skills.use_ability(1), "Cura com vida cheia não dispara"): return
	_used.clear()

	# 5d. Manobra: curva ×1,6 e volta
	skills._kinds[1] = "trick"
	skills._ability_cd.erase(1)
	if not _check(skills.use_ability(1) and absf(runner.turn_speed_degrees - base_turn * 1.6) < 0.001, "Manobra: curva ×1,6 (%.1f)" % runner.turn_speed_degrees): return
	await _wait(0.7)
	if not _check(absf(runner.turn_speed_degrees - base_turn) < 0.001, "a Manobra acabou"): return
	_used.clear()

	# 5e. Canhonada: empurra os rivais até 16 para longe do jogador; o de 24 fica
	skills._kinds[1] = "cannon"
	skills._ability_cd.erase(1)
	if not _check(skills.use_ability(1), "Canhonada com rivais por perto dispara"): return
	var away_b: Vector3 = (b.global_position - runner.global_position).normalized()
	if not _check(absf(b.push.length() - skills.cannon_push) < 0.1 and b.push.dot(away_b) > skills.cannon_push * 0.9, "a Canhonada empurra o rival para longe (%s)" % [b.push]): return
	if not _check(d.push.length() > 20.0 and d.push.dot((d.global_position - runner.global_position).normalized()) > 20.0, "e o outro rival de dentro também"): return
	if not _check(c.push.length() < 0.001, "o rival de fora do alcance fica onde está"): return
	_used.clear()

	# 5f. Armadura de Gelo: escudo
	skills._kinds[1] = "frost"
	skills._ability_cd.erase(1)
	health.shield_left = 0.0
	if not _check(skills.use_ability(1) and health.shield_left > 2.0, "Armadura de Gelo liga o escudo (%.2f)" % health.shield_left): return
	_used.clear()

	# 6. Fim de partida desfaz os efeitos e zera as cargas
	skills._kinds[1] = "lasso"
	skills._ability_cd.erase(1)
	skills.lasso_seconds = 30.0
	skills.use_ability(1)
	if not _check(absf(b.move_speed - base_b * 0.5) < 0.001, "pré-condição: Laço ligado"): return
	skills._reset()
	if not _check(absf(b.move_speed - base_b) < 0.001 and skills._timed.is_empty() and skills.ability_ready(1), "reset desfaz o efeito e zera as cargas"): return
	skills.lasso_seconds = 0.4
	_used.clear()

	# 7. Fora de campo não vale e não gasta a carga
	skills._kinds[1] = "trick"
	runner._aboard_ship = true
	if not _check(not skills.use_ability(1) and skills.ability_ready(1) and _used.is_empty(), "embarcado: a habilidade não gasta a carga"): return
	runner._aboard_ship = false

	# 8. Bots usam por regra (bots_sprint liga também as habilidades deles)
	skills._kinds[2] = "heal"
	skills._kinds[3] = "frost"
	skills._kinds[4] = "lasso"
	_far(b, runner, 0.9)
	_far(c, runner, -0.9)
	_far(d, runner, 0.0)
	skills.bots_sprint = true
	await _wait(0.3)
	if not _check(skills.ability_ready(2) and skills.ability_ready(3) and skills.ability_ready(4) and _used.is_empty(), "bots com vida cheia, sem rival por perto e sem alvo não gastam a carga"): return
	b.get_node("Health").points = b.get_node("Health").max_points - 8
	await _wait(0.3)
	if not _check(_used == [[2, "heal"]] and b.get_node("Health").points > b.get_node("Health").max_points - 8, "bot ferido usa a Cura (%s)" % [_used]): return
	_near(runner, c, 15.0)   # o jogador chega perto do bot 3: Armadura de Gelo
	await _wait(0.3)
	if not _check(_used.has([3, "frost"]) and c.get_node("Health").shield_left > 0.0, "bot com rival por perto usa a Armadura de Gelo (%s)" % [_used]): return
	skills.bots_sprint = false
	_used.clear()

	# 9. Trocar o bioma escolhido troca a habilidade do jogador (a ficha 1 vira a escolhida; a antiga vai para o lugar dela)
	var themes: Node = root.get_node("Services").themes
	var before_1: int = catalog.biome_of(1)
	var before_4: int = catalog.biome_of(4)
	themes.apply_choice(4)
	skills._kinds.clear()
	if not _check(before_1 != before_4 and catalog.biome_of(1) == before_4 and catalog.biome_of(4) == before_1, "a ficha 1 passou a ter o bioma que era da 4 e vice-versa (%d/%d)" % [before_1, before_4]): return
	if not _check(skills.ability_kind(1) == catalog.ability_of(before_4)["id"] and skills.ability_kind(4) == catalog.ability_of(before_1)["id"], "e as habilidades trocaram junto"): return

	# 10. Tela de civilizações: uma linha de habilidade por bioma
	var screen = load("res://scripts/ui/civilizations_screen.gd").new()
	root.add_child(screen)
	await process_frame
	for i in range(1, 7):
		var info: Label = screen.find_child("Skill%d" % i, true, false)
		if not _check(info != null and info.text.contains(catalog.ability_of(i)["name"]), "a tela mostra a habilidade do bioma %d" % i): return
	screen.queue_free()

	print("OK: habilidade do bioma — carga de 15 s na largada, E/botão, sem alvo não gasta, 6 efeitos, tempo e fim de partida desfazem, bot por regra, tela mostra")
	quit(0)
