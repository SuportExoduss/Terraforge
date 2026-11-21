extends SceneTree
## Teste de fumaça do Passo 144 (DD-184, substitui o toque-fecha do DD-127): cruzar o PRÓPRIO rastro fora da área NÃO fecha nada;
## o circuito só fecha quando o corredor VOLTA ao território já dominado (e aí o anel leva todo o rastro, cruzamento incluso).
## Território falso (círculo de 20 u em volta do polo); o teste põe o corredor ponto a ponto e dá os passos do rastro na mão.
## Uso: godot_console --headless --path . -s res://tools/smoke_selftouch.gd


class FakeTerritory extends RefCounted:
	var home := Vector3(0.0, 100.0, 0.0)

	func is_owned_by(_id: int, pos: Vector3) -> bool:
		return pos.distance_to(home) < 20.0

	func claim_cap(_id: int, _dir: Vector3, _angle: float) -> void:
		pass


var _fake := FakeTerritory.new()
var _trail: Node   # sem tipo: referenciar RunnerTrail aqui compilaria antes dos autoloads existirem
var _runner: Node3D
var _rings: Array = []   # tamanho de cada anel anunciado
var _frames := 0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	_trail = root.get_node("Main/Runner/Trail")
	_runner = root.get_node("Main/Runner")
	root.get_node("EventBus").territory_loop_closed.connect(func(_id, pts): _rings.append(pts.size()))


## Ponto da esfera de raio 100: `theta` = distância angular do polo (a área falsa acaba em ~0,2), `phi` = volta em torno dele.
func _at(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi)) * 100.0


func _check(ok: bool, what: String) -> bool:
	print(("OK    " if ok else "FALHOU ") + what)
	if not ok:
		quit(1)
	return ok


## Põe o corredor em `pos` e dá um passo do rastro (0,1 s).
func _walk(pos: Vector3) -> void:
	_runner.global_position = pos
	_trail._process(0.1)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	if _frames == 5:
		root.get_node("Services").territory = _fake
		_trail.set_process(false)    # o teste conduz o rastro sozinho
		_runner.set_process(false)   # e o corredor fica onde o teste o põe
		return false
	if not _runner.is_active_in_field():
		return _frames > 600 and not _check(false, "o corredor entrou em campo")

	_walk(_at(0.0, 0.0))             # dentro da área: nada grava
	# sai da área em linha reta (theta 0,05 -> 0,30) e dá uma volta inteira em torno dela, passando por cima do começo do rastro
	for k in 6:
		_walk(_at(0.05 + k * 0.05, 0.0))
	for k in 630:                    # volta completa (6,3 rad > 2π): o fim cruza o começo do próprio rastro
		_walk(_at(0.3, k * 0.01))
	var after_loop: int = _trail.points.size()
	if not _check(after_loop > 80, "o rastro gravou a volta inteira (%d pontos)" % after_loop): return true
	if not _check(_rings.is_empty(), "cruzar o próprio rastro NÃO fechou circuito (%s)" % [_rings]): return true
	for k in 40:                     # segue andando sobre o rastro já feito: continua gravando, continua aberto
		_walk(_at(0.3, 6.3 + k * 0.01))
	if not _check(_rings.is_empty() and _trail.points.size() > after_loop, "seguir sobre o próprio rastro continua gravando, sem fechar"): return true

	var before_return: int = _trail.points.size()
	for k in 6:                      # volta à área própria: theta 0,25 -> 0,0
		_walk(_at(0.25 - k * 0.05, 0.0))
	if not _check(_rings.size() == 1, "voltar à área própria fecha UM circuito (%s)" % [_rings]): return true
	if not _check(_rings[0] >= before_return, "o anel leva o rastro inteiro, cruzamento incluso (%d >= %d)" % [_rings[0], before_return]): return true
	if not _check(_trail.points.is_empty(), "rastro limpo depois de fechar"): return true
	print("OK")
	quit(0)
	return true
