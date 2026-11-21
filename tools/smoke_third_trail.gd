extends SceneTree
## Teste de fumaça do Passo 99 (SYS-001: "não é permitido fechar área utilizando trilhas de terceiros"): o circuito só conta
## os pontos do PRÓPRIO rastro. Encostar no rastro de um rival (a) não fecha nada, (b) corta o rival (DD-099) e (c) deixa o
## território e o rastro de quem encostou exatamente como estavam. O rival é um rastro falso (owner_id, points, cut) no Services.
## Uso: godot_console --headless --path . -s res://tools/smoke_third_trail.gd


class RivalTrail extends RefCounted:
	var owner_id := 2
	var points: Array = []
	var cut_by := -1

	func cut(attacker_id: int) -> void:
		cut_by = attacker_id


var _rival := RivalTrail.new()
var _trail: Node
var _runner: Node3D
var _map: Node
var _loops := 0
var _frames := 0
var _before: PackedByteArray
var _own_points := 0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	_trail = root.get_node("Main/Runner/Trail")
	_runner = root.get_node("Main/Runner")
	_map = root.get_node("Main/Territory")
	root.get_node("EventBus").territory_loop_closed.connect(func(_id, _pts): _loops += 1)


func _at(angle: float) -> Vector3:   # círculo de ~10 u no topo do planeta (mesmo do smoke_selftouch)
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
	if _frames == 5:
		_trail.set_process(false)   # o teste conduz o rastro sozinho
		_runner.set_process(false)  # e o corredor fica parado onde o teste o põe
		_trail.points.clear()
		for k in 20:                # rastro próprio: arco de 0 a 2,85 rad
			_trail.points.append(_at(k * 0.15))
		for k in 9:                 # rastro do rival: o arco do outro lado (3,2 a 4,4 rad), a ~8 u do rastro próprio
			_rival.points.append(_at(3.2 + k * 0.15))
		root.get_node("Services").register_trail(_rival)
		_own_points = _trail.points.size()
		_before = _map.owners_snapshot()
		# (a) o pé em cima do rival não fecha nada: a distância até o rastro PRÓPRIO é grande
		var foot: Vector3 = _rival.points[4]
		if not _check(_loops == 0, "o rastro do rival não faz parte do anel: nenhum circuito fecha"): return true
		# (b) o corredor para em cima do rival: o sensor de corte tem de agir
		_runner.global_position = foot
		return false
	if _rival.cut_by < 0 and _frames < 40:   # o sensor de corte olha a cada 0,08 s
		return false
	if not _check(_rival.cut_by == 1, "o rival foi cortado pelo jogador (cortado por %d)" % _rival.cut_by): return true
	if not _check(_loops == 0, "nenhum circuito fechou (%d)" % _loops): return true
	if not _check(_trail.points.size() == _own_points, "o rastro de quem encostou continua intacto"): return true
	if not _check(_map.owners_snapshot() == _before, "o território não mudou"): return true
	print("OK")
	quit(0)
	return true
