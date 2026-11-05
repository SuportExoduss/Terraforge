extends SceneTree
## Teste de fumaça do rastro: usa um território FALSO (círculo em volta do spawn) para checar
## (1) gravação ao sair, (2) fechamento de circuito ao voltar, (3) vigia da âncora (DD-123).
## Uso: godot_console --headless --path . -s res://tools/smoke_trail.gd


class FakeTerritory extends RefCounted:
	var home := Vector3(0.0, 100.0, 0.0)
	var owned_all := false

	func is_owned_by(_id: int, pos: Vector3) -> bool:
		return owned_all or pos.distance_to(home) < 20.0

	func claim_cap(_id: int, _dir: Vector3, _angle: float) -> void:
		pass   # a base do jogador também tenta reivindicar a calota


var _fake := FakeTerritory.new()
var _trail: Node   # sem tipo: referenciar RunnerTrail aqui compilaria antes dos autoloads existirem
var _time := 0.0
var _phase := 0
var _loops := 0
var _loop_points := 0
var _anchors := 0


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	_trail = root.get_node("Main/Runner/Trail")
	var bus := root.get_node("EventBus")
	bus.territory_loop_closed.connect(func(_id, pts): _loops += 1; _loop_points = pts.size())
	bus.trail_anchor_lost.connect(func(_id): _anchors += 1)
	# O _ready dos nós só roda no 1º quadro, e o TerritoryMap real se registra nele: o falso entra depois.


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	quit(1)


func _process(delta: float) -> bool:
	if _time == 0.0:
		root.get_node("Services").territory = _fake
	_time += delta
	match _phase:
		0:  # sai do círculo (raio 20 a 12 u/s) e grava cerca por alguns segundos
			if _time > 4.0:
				var visible_segments: int = _trail._pool.filter(func(s): return s.visible).size()
				print("fase0: pontos=%d cercas_visiveis=%d" % [_trail.points.size(), visible_segments])
				if _trail.points.size() < 3 or visible_segments < 2:
					return _finish_fail("rastro não gravou/plantou cercas")
				_fake.owned_all = true   # "voltou" ao território
				_phase = 1
		1:  # um frame depois: circuito fechado e rastro limpo
			print("fase1: loops=%d pts_evento=%d pontos_restantes=%d" % [_loops, _loop_points, _trail.points.size()])
			if _loops != 1 or _loop_points < 3 or not _trail.points.is_empty():
				return _finish_fail("circuito não fechou ou rastro não limpou")
			_fake.owned_all = false  # perdeu o chão de onde saiu
			_time = 0.0
			_phase = 2
		2:  # a vigia deve disparar em <= ~0.3 s depois de haver rastro
			if _time > 2.0:
				print("fase2: ancora_perdida=%d" % _anchors)
				if _anchors < 1:
					return _finish_fail("vigia da âncora não disparou")
				print("OK")
				quit(0)
	return false


func _finish_fail(msg: String) -> bool:
	_fail(msg)
	return true
