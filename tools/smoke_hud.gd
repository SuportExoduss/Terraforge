extends SceneTree
## Teste de fumaça do 6c (HUD): relógio, domínio, corações, contagem de respawn/GO!, aviso de evento,
## analógico flutuante e o recolhimento do relógio no fim. Só o jogador local (id 1) aparece.
## Uso: godot_console --headless --path . -s res://tools/smoke_hud.gd

var _match: Node
var _hud: Node
var _bus: Node
var _time := 0.0
var _phase := 0
var _started := false
var _joystick_checked := false


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_hud = _match.get_node("Hud")
	_bus = root.get_node("EventBus")
	_bus.match_started.connect(func(): _started = true)


func _fail(msg: String) -> bool:
	print("FALHOU: ", msg)
	quit(1)
	return true


func _text(node_name: String) -> String:
	return (_hud.find_child(node_name, true, false) as Label).text


func _process(delta: float) -> bool:
	_time += delta
	if _time > 20.0:
		return _fail("tempo esgotado na fase %d" % _phase)
	match _phase:
		0:
			if _started:
				_phase = 1
				_time = 0.0
		1:  # estados iniciais + eventos do jogador
			var hearts: Node = _hud.find_child("Hearts", true, false)
			if hearts.get_child_count() != 16:
				return _fail("esperava 16 quadrantes de vida, vieram %d" % hearts.get_child_count())
			var screen := _hud.get_viewport().get_visible_rect()
			for quadrant in hearts.get_children():
				if not screen.encloses((quadrant as Control).get_global_rect()):
					return _fail("coração fora da tela: %s (tela %s)" % [(quadrant as Control).get_global_rect(), screen])
			_bus.match_clock_changed.emit(125)
			if _text("ClockLabel") != "2:05":
				return _fail("relógio: '%s'" % _text("ClockLabel"))
			_bus.territory_score_changed.emit(2, 0.5)   # outro dono: ignorado
			_bus.territory_score_changed.emit(1, 0.0734)
			if _text("ScoreLabel") != "Domínio: 7,3%":
				return _fail("domínio: '%s'" % _text("ScoreLabel"))
			_bus.health_changed.emit(1, 10, 16)
			_bus.health_changed.emit(2, 0, 16)   # outro dono: ignorado
			var lit := 0
			for quadrant in hearts.get_children():
				if (quadrant as ColorRect).color == Color(1.0, 0.27, 0.32):
					lit += 1
			if lit != 10:
				return _fail("corações acesos: %d (esperava 10)" % lit)
			_bus.respawn_countdown.emit(1, 3)
			_bus.respawn_countdown.emit(2, 1)   # outro dono: ignorado
			if _text("CountdownLabel") != "3":
				return _fail("contagem: '%s'" % _text("CountdownLabel"))
			_bus.respawn_countdown.emit(1, 0)
			if _text("CountdownLabel") != "GO!":
				return _fail("esperava GO!")
			_bus.global_event_warning.emit("Meteoros", 5)
			if _text("EventLabel") != "Meteoros... 5":
				return _fail("aviso: '%s'" % _text("EventLabel"))
			_bus.global_event_warning.emit("Meteoros", 0)
			if _text("EventLabel") != "IMPACTO!":
				return _fail("esperava IMPACTO!")
			TouchSteering.begin(Vector2(100, 800))
			TouchSteering.set_value(0.5, Vector2(30, 0))
			_phase = 2
			_time = 0.0
		2:  # o analógico aparece; GO! e IMPACTO! somem sozinhos
			var joystick: CanvasItem = _hud.find_child("Joystick", true, false)
			if not _joystick_checked:
				_joystick_checked = true
				if not joystick.visible:
					return _fail("analógico deveria estar visível com o toque ativo")
				TouchSteering.clear()
			if _time > 1.4:
				if _text("CountdownLabel") != "" or _text("EventLabel") != "":
					return _fail("GO!/IMPACTO! deveriam ter sumido (sobrou '%s' / '%s')" % [_text("CountdownLabel"), _text("EventLabel")])
				_bus.match_ended.emit()
				if _text("ClockLabel") != "":
					return _fail("relógio deveria recolher no fim da partida")
				_phase = 3   # o _process do HUD esconde o analógico no quadro seguinte
		3:
			if (_hud.find_child("Joystick", true, false) as CanvasItem).visible:
				return _fail("analógico deveria sumir ao soltar o toque")
			print("OK")
			quit(0)
	return false
