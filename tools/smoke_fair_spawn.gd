extends SceneTree
## Teste de fumaça do Passo 58 (Cap.03 P02 CRITÉRIOS DE SPAWN): (1) as 6 bases da abertura ficam bem separadas
## (faces do cubo, >= 90°); (2) o pouso da nave nunca cai colado em outra base nem no foco de um evento em aviso/execução.
## Uso: godot_console --headless --path . -s res://tools/smoke_fair_spawn.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 5
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
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
		quit(1)
	return ok


func _dir(planet: Node, point: Vector3) -> Vector3:
	return (point - planet.center).normalized()


func _run() -> void:
	await _bus.match_started
	await process_frame
	var planet: Node = root.get_node("Services").planet
	var homes := get_nodes_in_group("home_base")
	if not _check(homes.size() == 6, "6 bases esperadas (%d)" % homes.size()): return

	# 1. Abertura: todo par de bases a pelo menos 90° (as faces do cubo)
	for i in homes.size():
		for j in range(i + 1, homes.size()):
			var arc := _dir(planet, homes[i].global_position).angle_to(_dir(planet, homes[j].global_position))
			if not _check(arc > PI / 2.0 - 0.01, "bases %d e %d a só %.2f rad" % [i, j, arc]): return

	# 2. Pouso: 200 sorteios, todos justos e longe das outras bases
	var home: Node = homes[0]
	var picks: Array[Vector3] = []
	for n in 200:
		var pick: Vector3 = home._pick_landing_position()
		picks.append(pick)
		if not _check(home.is_fair_spot(pick), "pouso injusto sorteado"): return
		for other in homes:
			if other == home:
				continue
			var arc := _dir(planet, pick).angle_to(_dir(planet, other.global_position))
			if not _check(arc >= home.MIN_BASE_ARC - 0.0001, "pouso a %.2f rad de outra base" % arc): return

	# 3. Colado em outra base (0,2 rad) é recusado; fora dos polos, então só a base explica a recusa
	var other_dir := _dir(planet, homes[1].global_position)
	var axis := other_dir.cross(Vector3.UP).normalized()
	var near_base: Vector3 = planet.center + other_dir.rotated(axis, 0.2) * planet.radius
	if not _check(not home.is_fair_spot(near_base), "pouso colado em outra base deveria ser recusado"): return

	# 4. Evento em aviso/execução: um foco falso no grupo do minimapa
	var script := GDScript.new()
	script.source_code = "extends Node\nvar dir := Vector3.UP\nfunc minimap_focus() -> Dictionary:\n\treturn {\"direction\": dir, \"heading\": Vector3.ZERO}\n"
	script.reload()
	var event := Node.new()
	event.set_script(script)
	event.add_to_group("minimap_events")
	root.add_child(event)
	var spot := _dir(planet, picks[0])
	var side := spot.cross(Vector3.UP).normalized()
	event.dir = spot
	if not _check(not home.is_fair_spot(picks[0]), "pouso em cima do evento deveria ser recusado"): return
	event.dir = spot.rotated(side, 0.3)
	if not _check(not home.is_fair_spot(picks[0]), "pouso a 0,3 rad do evento deveria ser recusado"): return
	event.dir = spot.rotated(side, 0.45)
	if not _check(home.is_fair_spot(picks[0]), "pouso a 0,45 rad do evento deveria ser aceito"): return
	event.dir = spot
	for n in 100:
		var pick: Vector3 = home._pick_landing_position()
		var arc := _dir(planet, pick).angle_to(spot)
		if not _check(arc >= home.EVENT_SAFE_ARC - 0.0001, "pouso sorteado a %.2f rad do evento" % arc): return

	print("OK: bases >= 90° na abertura; pouso longe de outras bases e de evento ativo")
	quit(0)
