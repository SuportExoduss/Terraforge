extends SceneTree
## Teste de fumaça do Passo 145 (DD-185): o minimapa mostra os JOGADORES e as BASES. (1) cor da marca = cor do solo com saturação/brilho
## mínimos; (2) marks() traz uma base por civilização e um corredor por jogador em campo, o jogador por último, cada um com cor própria e
## nome; (3) o jogador cai no centro da janela e a seta de rumo aponta para o topo (modo bússola); (4) rival no outro lado do planeta
## fica preso à borda (front=false); (5) corredor fora de campo (embarcado) some, a base fica; (6) minimapa aberto liga os nomes;
## (7) o disco de fundo 2D existe e não rouba toque; (8) _draw roda sem erro com tudo isso.
## Uso: godot_console --headless --path . -s res://tools/smoke_minimap_players.gd

var _match: Node
var _bus: Node
var _markers: Control
var _script: Script
var _time := 0.0


func _initialize() -> void:
	_script = load("res://scripts/ui/minimap_markers.gd")
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 2
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_markers = _match.get_node("Hud/Minimap/Markers")
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


## O dicionário `view` da câmera do minimapa agora (o mesmo que _draw monta).
func _view() -> Dictionary:
	var cam: Camera3D = _match.get_node("Hud/Minimap/SubViewport/MinimapCamera")
	var planet = root.get_node("Services").planet
	var offset: Vector3 = cam.global_position - planet.center
	var distance := offset.length()
	return {"cam_dir": offset / distance, "right": cam.global_basis.x, "up": cam.global_basis.y, "distance": distance,
			"radius": planet.radius, "tan_half": tan(deg_to_rad(cam.fov * 0.5))}


func _run() -> void:
	await _bus.match_started
	for i in 3:
		await process_frame

	# 1. Cor: solo apagado vira cor viva do mesmo matiz
	var dull := Color(0.3, 0.32, 0.3)
	var lit: Color = _script.marker_color(dull)
	if not _check(lit.s >= 0.5 - 0.001 and lit.v >= 0.9 - 0.001 and absf(lit.h - dull.h) < 0.01, "marker_color sobe saturação/brilho e mantém o matiz (s %.2f v %.2f)" % [lit.s, lit.v]): return
	var vivid := Color(0.9, 0.2, 0.2)
	if not _check(_script.marker_color(vivid).s >= vivid.s - 0.001, "cor já viva não perde saturação"): return

	# 2. marks(): bases + corredores, jogador por último
	var runner: Node3D = _match.get_node("Main/Runner")
	runner.set_process(false)   # o jogador fica parado: a câmera de bússola o mantém no centro
	var runners := get_nodes_in_group("runners")
	if not _check(runners.size() == 3, "pré-condição: 3 corredores em campo (%d)" % runners.size()): return
	await process_frame
	await process_frame
	var marks: Array = _markers.marks(_view())
	var bases: Array = marks.filter(func(m): return m["kind"] == "base")
	var walkers: Array = marks.filter(func(m): return m["kind"] == "runner")
	var homes: Dictionary = root.get_node("Services").home_bases
	if not _check(bases.size() == homes.size() and bases.size() >= 3, "uma base por civilização (%d de %d)" % [bases.size(), homes.size()]): return
	if not _check(walkers.size() == 3, "um corredor por jogador em campo (%d)" % walkers.size()): return
	if not _check(marks.back()["kind"] == "runner" and marks.back()["player"], "o jogador é desenhado por último (por cima)"): return
	var colors: Array = []
	for m in walkers:
		if not _check(str(m["name"]) != "", "toda marca tem nome (civ %d)" % m["id"]): return
		for other: Color in colors:
			if not _check(absf(other.r - m["color"].r) + absf(other.g - m["color"].g) + absf(other.b - m["color"].b) > 0.15, "cores dos jogadores distintas (civ %d)" % m["id"]): return
		colors.append(m["color"])

	# 3. Jogador no centro; seta de rumo para o topo (y negativo)
	var mine: Dictionary = marks.back()
	if not _check((mine["pos"] as Vector2).length() < 0.05 and mine["front"], "o jogador cai no centro do minimapa (%s)" % [mine["pos"]]): return
	var step: Vector2 = mine["heading"]
	if not _check(step.y < -0.9 and absf(step.x) < 0.3, "a seta de rumo do jogador aponta para o topo (%s)" % [step]): return

	# 4. Rival no outro lado do planeta: preso à borda, sem rumo
	var planet = root.get_node("Services").planet
	var rival: Node3D = _match.get_node("Main/Runner2")
	rival.set_process(false)
	rival.teleport_to(planet.center - (runner.global_position - planet.center))
	await process_frame
	await process_frame
	var rival_id: int = rival.get_node("Civilization").id
	var far: Dictionary = {}
	for m: Dictionary in _markers.marks(_view()):
		if m["kind"] == "runner" and m["id"] == rival_id:
			far = m
	if not _check(not far.is_empty() and not far["front"] and (far["pos"] as Vector2).length() > _script.EDGE_LIMIT - 0.001, "rival do outro lado fica preso à borda (%s)" % [far]): return
	if not _check(far["heading"] == Vector2.ZERO, "sem seta de rumo para quem está do outro lado"): return

	# 5. Embarcado (fora de campo) some; a base fica
	var bot: Node3D = _match.get_node("Main/Runner3")
	var bot_id: int = bot.get_node("Civilization").id
	bot._aboard_ship = true
	var after: Array = _markers.marks(_view())
	var bot_runner := after.filter(func(m): return m["kind"] == "runner" and m["id"] == bot_id)
	var bot_base := after.filter(func(m): return m["kind"] == "base" and m["id"] == bot_id)
	bot._aboard_ship = false
	if not _check(bot_runner.is_empty() and bot_base.size() == 1, "corredor fora de campo some, a base fica"): return

	# 6. Minimapa aberto liga os nomes
	_bus.minimap_held.emit(true)
	var expanded_on: bool = _markers._expanded
	await process_frame
	_bus.minimap_held.emit(false)
	if not _check(expanded_on and not _markers._expanded, "minimapa aberto liga os nomes; fechar desliga"): return

	# 7. Disco de fundo 2D
	var backdrop := _match.get_node_or_null("Hud/Minimap/Backdrop") as Panel
	if not _check(backdrop != null and backdrop.show_behind_parent and backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "disco de fundo existe, fica atrás do planeta e não rouba toque"): return

	# 8. _draw roda (aberto e fechado) sem erro
	_markers.queue_redraw()
	await process_frame
	_bus.minimap_held.emit(true)
	_markers.queue_redraw()
	await process_frame
	_bus.minimap_held.emit(false)

	print("OK: minimapa mostra bases e jogadores (cor, nome, rumo, borda do planeta, fora de campo) e tem disco de fundo 2D")
	quit(0)
