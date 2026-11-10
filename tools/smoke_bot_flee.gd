extends SceneTree
## Teste de fumaça do Passo 61 (Cap.05 P05 "Resposta aos eventos"): o bot (1) volta para casa quando está fora dela e perto
## de um evento em aviso/execução; (2) não escolhe alvo de surtida dentro da zona do evento; (3) volta ao normal quando o
## evento passa. Uso: godot_console --headless --path . -s res://tools/smoke_bot_flee.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 40.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var planet: Node = root.get_node("Services").planet
	var rival: Node3D = _match.get_node("Main/Runner2")
	var bot: Node = rival.get_node("Steering")
	var bot_id: int = rival.get_node("Civilization").id
	var territory: Node = root.get_node("Services").territory

	# Evento falso: grupo do minimapa, foco controlável; vazio = fora de aviso/execução
	var script := GDScript.new()
	script.source_code = "extends Node\nvar dir := Vector3.ZERO\nfunc minimap_focus() -> Dictionary:\n\tif dir == Vector3.ZERO:\n\t\treturn {}\n\treturn {\"direction\": dir, \"heading\": Vector3.ZERO}\n"
	script.reload()
	var event := Node.new()
	event.set_script(script)
	event.add_to_group("minimap_events")
	root.add_child(event)

	# Bot fora de casa: 1,0 rad da própria base, em terra que não é dele
	var home_dir: Vector3 = (root.get_node("Services").home_bases[bot_id]["position"] - planet.center).normalized()
	var axis: Vector3 = home_dir.cross(Vector3.UP).normalized()
	var far_dir: Vector3 = home_dir.rotated(axis, 1.0)
	var far_point: Vector3 = planet.center + far_dir * planet.get_surface_radius(far_dir)
	if not _check(not territory.is_owned_by(bot_id, far_point), "o ponto de teste deveria estar fora do território do bot"): return
	rival.teleport_to(far_point)

	# 1. Sem evento: segue a vida (nada de volta para casa por perigo)
	await create_timer(0.7).timeout
	if not _check(not bot._fleeing and not bot._returning_home, "sem evento o bot não foge"): return

	# 2. Evento em cima dele: foge para casa
	var here: Vector3 = (rival.global_position - planet.center).normalized()
	event.dir = here
	await create_timer(0.7).timeout
	if not _check(bot._fleeing and bot._returning_home, "com evento por perto o bot volta para casa"): return

	# 3. Evento longe (0,8 rad) não assusta
	event.dir = here.rotated(here.cross(Vector3.UP).normalized(), 0.8)
	await create_timer(0.7).timeout
	if not _check(not bot._fleeing, "evento a 0,8 rad não assusta"): return

	# 4. Surtida: com a zona do evento à frente, nenhum alvo escolhido cai dentro dela (o recuo "para frente" fica fora)
	var up: Vector3 = (rival.global_position - planet.center).normalized()   # o bot andou desde o passo 2
	var forward: Vector3 = rival.forward
	var side: Vector3 = up.cross(forward).normalized()
	var arc: float = bot.EVENT_AVOID_ARC + bot.min_sortie_distance / planet.radius + 0.1
	event.dir = up.rotated(side, arc)   # a zona começa um pouco além do recuo (frente a 20 m): parte dos alvos cairia nela
	bot._danger = bot._danger_directions()
	bot.ambition = 1.0
	var inside := 0
	for n in 300:
		var target: Vector3 = bot._pick_sortie_target()
		var angle: float = ((target - planet.center).normalized()).angle_to(event.dir)
		if angle < bot.EVENT_AVOID_ARC - 0.0001:
			inside += 1
	if not _check(inside == 0, "%d alvos de surtida dentro da zona do evento" % inside): return

	# 5. O evento acaba: tudo volta ao normal
	event.dir = Vector3.ZERO
	await create_timer(0.7).timeout
	if not _check(bot._danger.is_empty() and not bot._fleeing, "sem evento o perigo some"): return

	print("OK: bot foge de evento por perto, não escolhe surtida dentro da zona e volta ao normal")
	quit(0)
