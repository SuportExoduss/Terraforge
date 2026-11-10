extends SceneTree
## Teste de fumaça do Passo 70 (Cap.03 P11 "observar cada civilização / analisar estratégias"): TAB na contemplação mostra uma
## legenda com nome, domínio, colocação e estatísticas da civilização observada; girar à mão esconde a legenda.
## Uso: godot_console --headless --path . -s res://tools/smoke_contemplation_caption.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 2
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _tab() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	return ev


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var cam: Node = _match.get_node("Main/Contemplation")
	var stats: Node = root.get_node("Services").stats

	_bus.territory_score_changed.emit(1, 0.30)
	_bus.territory_score_changed.emit(2, 0.12)
	_bus.territory_score_changed.emit(3, 0.05)
	_bus.territory_cells_converted.emit(2, 0.04)
	_bus.trail_cut.emit(3, 2)
	_bus.match_ended.emit()
	if not _check(cam._caption == null, "sem TAB ainda não há legenda"): return

	cam._unhandled_input(_tab())   # civilização 1 = jogador
	if not _check(cam._caption != null and cam._caption.visible, "TAB deveria mostrar a legenda"): return
	var t1: String = cam._caption.text
	if not _check(t1.contains("VOCÊ") and t1.contains("30,0%") and t1.contains("(1º)"), "legenda do jogador: " + t1): return

	cam._unhandled_input(_tab())   # civilização 2: 12% (2º), tomou 4% de rivais e cortou 1 rastro
	var t2: String = cam._caption.text
	if not _check(t2.contains("CIVILIZAÇÃO 2") and t2.contains("12,0%") and t2.contains("(2º)") and t2.contains("Tomado de rivais 4,0%") and t2.contains("Cortes 1"), "legenda da civ 2: " + t2): return

	# Eliminada: mostra o auge e o aviso
	_bus.civilization_eliminated.emit(3)
	cam._unhandled_input(_tab())
	var t3: String = cam._caption.text
	if not _check(t3.contains("CIVILIZAÇÃO 3") and t3.contains("5,0%") and t3.contains("ELIMINADA"), "legenda da civ 3 eliminada: " + t3): return

	# Girar à mão esconde a legenda
	cam._drag = Vector2(50, 0)
	await process_frame
	if not _check(not cam._caption.visible, "arrastar deveria esconder a legenda"): return
	print("OK: TAB mostra nome, domínio, colocação e estatísticas da civilização observada; arrastar esconde")
	quit(0)
