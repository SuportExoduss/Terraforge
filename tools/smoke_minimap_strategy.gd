extends SceneTree
## Teste de fumaça do Passo 33 (minimapa estratégico, MP-003..007 / DD-131): (1) a projeção das marcas confere com a
## câmera de verdade e, do outro lado do planeta, prende a marca à borda; (2) o aviso/execução do evento global chega
## ao minimapa (nome, contagem, ao vivo) e cada evento diz onde está e para onde anda; (3) bônus aparecem como marcas;
## (4) zoom (roda e pinça) só com o minimapa aberto, limitado, sem mexer no enquadramento e zerado ao fechar.
## Uso: godot_console --headless --path . -s res://tools/smoke_minimap_strategy.gd

var _match: Node
var _bus: Node
var _markers: Control
var _view: Control
var _cam: Camera3D
var _markers_script: Script
var _failed := false


func _initialize() -> void:
	_markers_script = load("res://scripts/ui/minimap_markers.gd")
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_view = _match.get_node("Hud/Minimap")
	_markers = _match.get_node("Hud/Minimap/Markers")
	_cam = _match.get_node("Hud/Minimap/SubViewport/MinimapCamera")
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _wheel(button: int) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = true
	return click


func _run() -> void:
	await _bus.match_started
	for i in 3:
		await process_frame
	var planet = root.get_node("Services").planet
	var radius: float = planet.radius
	var offset: Vector3 = _cam.global_position - planet.center
	var distance := offset.length()
	var cam_dir := offset / distance
	var basis := _cam.global_basis
	var tan_half := tan(deg_to_rad(_cam.fov * 0.5))

	# 1. Projeção = a da câmera de verdade (viewport 400x400)
	var samples := [
		cam_dir,
		cam_dir.rotated(basis.y, deg_to_rad(25.0)).rotated(basis.x, deg_to_rad(-15.0)),
		cam_dir.rotated(basis.x, deg_to_rad(40.0)),
		cam_dir.rotated(basis.y, deg_to_rad(-55.0)).rotated(basis.x, deg_to_rad(20.0)),
	]
	for d in samples:
		var placed: Dictionary = _markers_script.project(d, cam_dir, basis.x, basis.y, distance, radius, tan_half)
		var truth := _cam.unproject_position(planet.center + d * radius) / 200.0 - Vector2.ONE
		_check(placed["front"], "a amostra deveria estar do lado visível")
		_check((placed["pos"] as Vector2).distance_to(truth) < 0.01, "projeção %s difere da câmera %s" % [placed["pos"], truth])
	var behind: Dictionary = _markers_script.project(-cam_dir, cam_dir, basis.x, basis.y, distance, radius, tan_half)
	_check(not behind["front"], "o outro lado do planeta não é visível")
	var rim: float = radius / (sqrt(distance * distance - radius * radius) * tan_half)
	_check(absf((behind["pos"] as Vector2).length() - rim) < 0.001, "marca de trás deve ficar na borda da silhueta")
	var side := cam_dir.rotated(basis.y, acos(radius / distance) + 0.02)   # logo depois do horizonte
	var hidden: Dictionary = _markers_script.project(side, cam_dir, basis.x, basis.y, distance, radius, tan_half)
	var shown: Dictionary = _markers_script.project(cam_dir.rotated(basis.y, acos(radius / distance) - 0.02), cam_dir, basis.x, basis.y, distance, radius, tan_half)
	_check(not hidden["front"] and shown["front"], "o horizonte separa visível de oculto")
	_check(absf((hidden["pos"] as Vector2).length() - (shown["pos"] as Vector2).length()) < 0.1, "a marca não pode saltar ao cruzar o horizonte")

	# 2. Aviso e execução chegam ao minimapa
	_check(not _markers.event_live(), "sem evento, o minimapa fica limpo")
	_bus.global_event_warning.emit("TSUNAMI VINDO", 4)
	_check(_markers.event_live() and _markers.event_name == "TSUNAMI VINDO" and _markers.event_seconds == 4, "aviso não chegou ao minimapa")
	_bus.global_event_active_changed.emit(true)
	_check(_markers.event_live() and _markers.event_seconds == 0, "em execução não há mais contagem")
	_bus.global_event_active_changed.emit(false)
	_check(not _markers.event_live(), "evento acabou: minimapa limpo")
	_bus.global_event_warning.emit("TSUNAMI VINDO", 2)
	_bus.match_ended.emit()
	_check(not _markers.event_live(), "fim da partida limpa o aviso")
	_bus.match_started.emit()

	# 3. Cada evento sabe onde está e para onde anda (estado em aviso)
	var events := get_nodes_in_group("minimap_events")
	_check(events.size() >= 7, "os 7 eventos devem se registrar no minimapa (%d)" % events.size())
	var saw_heading := false
	for node in events:
		_check(node.minimap_focus().is_empty(), "%s: sem aviso nem execução não há local" % node.name)
	var tsunami = _match.get_node("Tsunami")
	tsunami.plan(Vector3.UP, Vector3.RIGHT)
	tsunami.state = 2   # GlobalEvent.State.WARNING
	var focus: Dictionary = tsunami.minimap_focus()
	_check(not focus.is_empty() and focus["direction"].distance_to(Vector3.UP) < 0.01, "o tsunami deve apontar o ponto de partida")
	_check(absf((focus["heading"] as Vector3).dot(focus["direction"])) < 0.01 and (focus["heading"] as Vector3).length() > 0.9, "o rumo do tsunami é tangente ao chão")
	tsunami.state = 1
	_check(tsunami.minimap_focus().is_empty(), "tsunami fora de aviso/execução não aparece")
	var volcano = _match.get_node("Volcano")
	volcano.plan(Vector3.RIGHT)
	volcano.state = 3   # ACTIVE
	focus = volcano.minimap_focus()
	_check(not focus.is_empty() and focus["direction"].distance_to(Vector3.RIGHT) < 0.01, "o vulcão deve apontar a boca")
	_check(focus["heading"] == Vector3.ZERO, "vulcão não anda: sem seta de rumo")
	volcano.state = 1
	for name in ["Hurricane", "AcidRain"]:
		var moving = _match.get_node(name)
		moving.plan(Vector3.BACK, Vector3.UP)
		moving.state = 3
		focus = moving.minimap_focus()
		_check(not focus.is_empty() and (focus["heading"] as Vector3).length() > 0.9, "%s deve informar o rumo" % name)
		saw_heading = true
		moving.state = 1
	_check(saw_heading, "pelo menos um evento móvel")

	# 4. Bônus viram marcas
	var before := get_nodes_in_group("bonus_pickups").size()
	_bus.bonus_drop_requested.emit(planet.center + Vector3.UP * radius, 2)
	var pickups := get_nodes_in_group("bonus_pickups")
	_check(pickups.size() == before + 2, "o drop deveria criar 2 bônus (%d -> %d)" % [before, pickups.size()])
	_check(_markers.call("_bonus_color", pickups[-1]) != Color.WHITE, "o bônus deve ter cor própria no minimapa")
	_bus.global_event_active_changed.emit(true)
	await process_frame
	await process_frame   # exercita o _draw com bônus e evento

	# 5. Zoom
	var zooms := []
	_bus.minimap_zoomed.connect(func(factor: float): zooms.append(factor))
	_view._gui_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	_check(zooms.is_empty() and _cam.zoom == 1.0, "com o minimapa fechado a roda não dá zoom")
	_view._toggle()   # abre
	_view._gui_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	_check(zooms.size() == 1 and zooms[0] > 1.0, "roda para cima deve aproximar")
	_view._gui_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	_check(zooms.size() == 2 and zooms[1] < 1.0, "roda para baixo deve afastar")
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.5
	_view._gui_input(pinch)
	_check(zooms.size() == 3 and is_equal_approx(zooms[2], 1.5), "a pinça deve repassar o fator")
	await process_frame
	var base_distance: float = (_cam.global_position - planet.center).length()
	_cam.zoom = 1.0
	_bus.minimap_zoomed.emit(2.0)
	_check(is_equal_approx(_cam.zoom, 2.0), "zoom 2x (%.2f)" % _cam.zoom)
	await process_frame
	_check(absf(tan(deg_to_rad(_cam.fov * 0.5)) * 2.0 - tan(deg_to_rad(15.0))) < 0.001, "zoom 2x deve estreitar o campo de visão (%.2f)" % _cam.fov)
	_check(absf((_cam.global_position - planet.center).length() - base_distance) < 0.01, "o zoom não muda a distância da câmera")
	_bus.minimap_zoomed.emit(10.0)
	_check(is_equal_approx(_cam.zoom, _cam.max_zoom), "o zoom tem teto (%.2f)" % _cam.zoom)
	_bus.minimap_zoomed.emit(0.01)
	_check(is_equal_approx(_cam.zoom, 1.0), "o zoom não afasta além do enquadramento (%.2f)" % _cam.zoom)
	_bus.minimap_zoomed.emit(2.0)
	_view._toggle()   # fecha
	_check(is_equal_approx(_cam.zoom, 1.0), "ao fechar o minimapa o zoom volta a 1x")
	await process_frame
	_check(is_equal_approx(_cam.fov, 30.0), "campo de visão original de volta (%.2f)" % _cam.fov)
	_bus.minimap_zoomed.emit(2.0)
	_check(is_equal_approx(_cam.zoom, 1.0), "fechado, o zoom não muda")

	if not _failed:
		print("OK")
		quit(0)
