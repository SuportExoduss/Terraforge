extends SceneTree
## Teste de fumaça do 6d: (1) minimapa em BÚSSOLA — a câmera-satélite paira sobre o jogador, olha o centro
## do planeta e leva a frente do corredor ao topo; (2) um toque abre (centro da tela, 75% de opacidade) e
## solta o analógico; (3) arrastar gira a órbita no sentido certo e larga o jogador; (4) outro toque volta;
## (5) no fim da partida a câmera principal se afasta até enquadrar o planeta e a vitrine gira sozinha.
## Uso: godot_console --headless --path . -s res://tools/smoke_minimap.gd

var _match: Node
var _bus: Node
var _planet: Node
var _minimap: Control
var _cam: Camera3D        # câmera-satélite
var _main_cam: Camera3D   # câmera principal
var _runner: Node3D
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_planet = root.get_node("Services").planet   # ainda nulo aqui; relido em _run
	_minimap = _match.get_node("Hud/Minimap")
	_cam = _match.get_node("Hud/Minimap/SubViewport/MinimapCamera")
	_main_cam = _match.get_node("Main/Camera")
	_runner = _match.get_node("Main/Runner")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _dir(node: Node3D) -> Vector3:
	return (node.global_position - _planet.center).normalized()


func _click(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	_minimap._gui_input(e)


func _tap() -> void:
	_click(true)
	_click(false)


func _run() -> void:
	await _bus.match_started
	await _frames(20)
	_planet = root.get_node("Services").planet
	var R: float = _planet.radius

	# 1. Bússola
	var d_cam := _dir(_cam)
	if not _check(rad_to_deg(d_cam.angle_to(_dir(_runner))) < 2.0, "satélite fora de cima do jogador (%.1f°)" % rad_to_deg(d_cam.angle_to(_dir(_runner)))): return
	if not _check((-_cam.global_basis.z).dot((_planet.center - _cam.global_position).normalized()) > 0.999, "satélite não olha o centro"): return
	if not _check(_cam.global_basis.y.dot(_runner.global_basis.z) > 0.98, "frente do corredor não está no topo (%.3f)" % _cam.global_basis.y.dot(_runner.global_basis.z)): return
	var want := R / sin(deg_to_rad(_cam.fov * 0.5) * _cam.planet_fill_factor)
	if not _check(absf(_cam.global_position.distance_to(_planet.center) - want) < 1.0, "distância de enquadramento"): return
	if not _check(_minimap.get_global_rect().get_center().x > 400.0 and _minimap.get_global_rect().get_center().y < 150.0, "minimapa deveria estar no canto superior direito: %s" % _minimap.get_global_rect()): return

	# 2. Um toque abre
	var held := []
	_bus.minimap_held.connect(func(h): held.append(h))
	_click(true)
	if not _check(TouchSteering.is_ui_pointer_held, "apertar o minimapa deveria segurar o analógico"): return
	_click(false)
	if not _check(not TouchSteering.is_ui_pointer_held, "soltar deveria liberar o analógico"): return
	await _frames(2)
	if not _check(held == [true], "toque deveria abrir uma vez: %s" % [held]): return
	var screen := root.get_visible_rect()
	if not _check(_minimap.get_global_rect().get_center().distance_to(screen.get_center()) < 2.0, "aberto deveria estar no centro: %s" % _minimap.get_global_rect()): return
	if not _check(is_equal_approx(_minimap.modulate.a, 0.75), "opacidade aberta"): return

	# 3. Arrastar: a câmera vai para o lado OPOSTO (o planeta acompanha o dedo) e larga o jogador
	await _frames(2)
	var before := _cam.global_position
	var right := _cam.global_basis.x
	_click(true)
	var m := InputEventMouseMotion.new()
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	m.relative = Vector2(50, 0)
	_minimap._gui_input(m)
	_click(false)
	await _frames(2)
	var turned := rad_to_deg(_dir(_cam).angle_to((before - _planet.center).normalized()))
	if not _check(absf(turned - 20.0) < 1.5, "50 px deveriam girar ~20° (girou %.1f°)" % turned): return
	if not _check((_cam.global_position - before).dot(right) < 0.0, "arrastar à direita deveria levar a câmera à esquerda"): return
	if not _check(held == [true], "arrastar não pode fechar o minimapa: %s" % [held]): return
	await _frames(30)
	if not _check(rad_to_deg(_dir(_cam).angle_to(_dir(_runner))) > 5.0, "aberto não deveria seguir o jogador"): return

	# 4. Outro toque fecha e volta à bússola
	_tap()
	await _frames(5)
	if not _check(held == [true, false], "segundo toque deveria fechar: %s" % [held]): return
	if not _check(rad_to_deg(_dir(_cam).angle_to(_dir(_runner))) < 2.0, "fechado deveria voltar a seguir o jogador"): return

	# 5. Contemplação: no fim a câmera principal se afasta e a vitrine gira sozinha
	_bus.match_ended.emit()
	await create_timer(5.0).timeout
	var far := _main_cam.global_position.distance_to(_planet.center)
	var d0 := _dir(_main_cam)
	await create_timer(1.0).timeout
	var swept := rad_to_deg(d0.angle_to(_dir(_main_cam)))
	if not _check(absf(far - R * 3.5) < 8.0, "afastamento: %.0f (esperava ~%.0f)" % [far, R * 3.5]): return
	if not _check((-_main_cam.global_basis.z).dot((_planet.center - _main_cam.global_position).normalized()) > 0.999, "contemplação deveria olhar o centro"): return
	if not _check(absf(swept - 10.0) < 2.0, "vitrine deveria girar ~10°/s (girou %.1f°)" % swept): return
	print("OK")
	quit(0)
