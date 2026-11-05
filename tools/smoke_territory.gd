extends SceneTree
## Teste ponta a ponta do território: o corredor de verdade sai da calota, desenha um quadrado,
## volta ao território, o rastro fecha o circuito e a thread do TerritoryMap conquista o interior.
## Confere também que a âncora (DD-123) NÃO dispara e mede o pior quadro durante a conquista.
## Uso: godot_console --headless --path . -s res://tools/smoke_territory.gd

# (duração em segundos, curva à direita?) — lados de 1,5 s (~18 u) com curvas de 90 graus (0,5 s).
const ROUTE := [[1.5, false], [0.5, true], [1.5, false], [0.5, true], [1.5, false], [0.5, true], [4.0, false]]

var _map: Node       # sem tipo: referenciar TerritoryMap aqui compilaria antes dos autoloads existirem
var _runner: Node3D
var _time := 0.0
var _started := false
var _loops := 0
var _anchors := 0
var _claimed_cells := 0
var _claims := 0
var _initial_cells := 0
var _loop_time := -1.0
var _worst_ms := 0.0
var _path_sum := Vector3.ZERO
var _path_n := 0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()   # sem a descida de abertura (7 s)
	root.add_child(main_scene)
	_map = root.get_node("Main/Territory")
	_runner = root.get_node("Main/Runner")
	var bus := root.get_node("EventBus")
	bus.territory_loop_closed.connect(func(_id, _pts):
		_loops += 1
		_loop_time = _time
		_claims = 0   # só contam os anúncios feitos a partir do fechamento (a calota já foi anunciada)
		_claimed_cells = 0)
	bus.trail_anchor_lost.connect(func(_id): _anchors += 1)
	bus.territory_cells_claimed.connect(func(owner, cells, _spacing):
		if owner == 1:
			_claims += 1
			_claimed_cells += cells.size())


func _process(delta: float) -> bool:
	if not _started:
		if _map._counts[1] == 0:   # espera a base reivindicar a calota
			return false
		_started = true
		_initial_cells = _map._counts[1]
		_time = 0.0
		return false
	_time += delta

	if _loop_time < 0.0:
		_steer(_time)
		_path_sum += (_runner.global_position).normalized()
		_path_n += 1
		if _time > 12.0:
			return _fail("o circuito não fechou em 12 s")
		return false

	# Circuito fechado: a conquista corre na thread; só o pior quadro importa aqui.
	Input.action_release("ui_right")
	_worst_ms = maxf(_worst_ms, delta * 1000.0)
	if _claims == 0 and _time - _loop_time < 3.0:
		return false
	return _verify()


func _steer(t: float) -> void:
	var at := 0.0
	for leg in ROUTE:
		at += leg[0]
		if t < at:
			if leg[1]:
				Input.action_press("ui_right")
			else:
				Input.action_release("ui_right")
			return
	Input.action_release("ui_right")


func _verify() -> bool:
	var center := (_path_sum / _path_n).normalized() * 100.0
	var cells: int = _map._counts[1]
	print("células iniciais=%d  finais=%d  anunciadas=%d (em %d anúncio(s))" % [_initial_cells, cells, _claimed_cells, _claims])
	print("circuitos=%d  âncora_perdida=%d  pior_quadro_após_fechar=%.1f ms" % [_loops, _anchors, _worst_ms])
	var ok := true
	if _loops != 1: ok = _no("esperava 1 circuito")
	if _anchors != 0: ok = _no("a âncora disparou com o território real (DD-123)")
	if _claims < 1 or _claimed_cells < 50: ok = _no("a conquista não foi anunciada")
	if cells < _initial_cells + 50: ok = _no("o território não cresceu")
	if not _map.is_owned_by(1, center): ok = _no("o miolo do circuito não é do jogador")
	if _map.owned_fraction(1) <= float(_initial_cells) / _map.cell_count: ok = _no("placar não subiu")
	print("OK" if ok else "FALHOU")
	quit(0 if ok else 1)
	return true


func _no(msg: String) -> bool:
	print("  FALHOU: ", msg)
	return false


func _fail(msg: String) -> bool:
	print("FALHOU: ", msg)
	quit(1)
	return true
