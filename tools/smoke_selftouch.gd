extends SceneTree
## Teste de fumaça (DD-127): encostar no PRÓPRIO rastro fecha o circuito na hora.
## Rastro sintético em círculo (raio ~10) no topo do planeta; sem depender do corredor andar.
## Uso: godot_console --headless --path . -s res://tools/smoke_selftouch.gd

var _trail: Node
var _rings: Array = []
var _frames := 0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	_trail = root.get_node("Main/Runner/Trail")
	root.get_node("EventBus").territory_loop_closed.connect(func(_id, pts): _rings.append(pts.size()))


func _at(angle: float) -> Vector3:
	var s := sin(0.1)
	return Vector3(s * cos(angle), cos(0.1), s * sin(angle)) * 100.0


func _check(ok: bool, what: String) -> bool:
	print(("OK    " if ok else "FALHOU ") + what)
	if not ok:
		quit(1)
	return ok


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	_trail.set_process(false)   # o teste conduz o rastro sozinho
	_trail.points.clear()
	for k in 40:   # arco de 0 a 5,85 rad (a 1,5 u de distância): falta ~0,43 rad para fechar o círculo
		_trail.points.append(_at(k * 0.15))

	if not _check(not _trail._close_on_self_touch(_at(5.9), 1.0) and _rings.is_empty(), "perto da cauda recém-gravada não fecha"): return true
	if not _check(not _trail._close_on_self_touch(_at(3.0) * 1.2, 1.0) and _rings.is_empty(), "longe do rastro não fecha"): return true
	if not _check(_trail._close_on_self_touch(_at(6.2), 1.0), "encostar no começo do rastro fecha"): return true
	if not _check(_rings == [40], "anel = pontos depois do tocado + o ponto atual (veio %s)" % [_rings]): return true
	if not _check(_trail.points.is_empty() and _trail._grace > 0.0, "rastro limpo e sem gravar por um instante"): return true
	print("OK")
	quit(0)
	return true
