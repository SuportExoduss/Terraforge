extends SceneTree
## Teste de fumaça do Passo 105 (DD-140, ruína da civilização eliminada): ao ser eliminada, o território dela FICA no mapa (nada some
## nem vira de ninguém sozinho), conta como dela (a ruína pintada em piso morto, DD-122) e CONTINUA conquistável: um laço da civilização 1
## em volta dele converte todas as células para a 1 e o placar da eliminada zera.
## Uso: godot_console --headless --path . -s res://tools/smoke_ruin_territory.gd

const POINTS := 96
const RUIN_DIR := Vector3.RIGHT
const RUIN_CAP := 0.35          # radianos
const LOOP_DEG := 40.0          # laço bem maior que a calota (0,35 rad = 20°)

var _map: Node       # sem tipo: referenciar TerritoryMap aqui compilaria antes dos autoloads existirem
var _bus: Node
var _time := 0.0
var _done := false


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	quit(1)


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	_map = root.get_node("Main/Territory")
	_bus = root.get_node("EventBus")


func _circle(c: Vector3, deg: float) -> PackedVector3Array:
	var u := c.cross(Vector3.UP).normalized()
	var v := c.cross(u)
	var pts := PackedVector3Array()
	for i in POINTS:
		var a := TAU * i / POINTS
		var dir := c * cos(deg_to_rad(deg)) + (u * cos(a) + v * sin(a)) * sin(deg_to_rad(deg))
		pts.append(_map._center_cache + dir.normalized() * _map._radius)
	return pts


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		_fail("tempo esgotado")
	elif not _done and _map._counts[1] > 0:   # a base já reivindicou a calota
		_done = true
		_verify()
	return false


func _verify() -> void:
	_map.claim_cap(2, RUIN_DIR, RUIN_CAP)
	var ruin: int = _map._counts[2]
	if ruin < 20:
		return _fail("a civilização 2 deveria ter a calota (%d células)" % ruin)
	_bus.civilization_eliminated.emit(2)
	for i in 5:   # o território não deve mudar sozinho com o tempo/eventos
		_map._process(0.1)
	if _map._counts[2] != ruin:
		return _fail("a ruína perdeu células sem ninguém conquistar (%d -> %d)" % [ruin, _map._counts[2]])
	if _map.get_owner_at(_map._center_cache + RUIN_DIR * _map._radius) != 2:
		return _fail("o centro da ruína deveria continuar marcado como da civilização 2")
	var mine_before: int = _map._counts[1]
	_map.claim_loop_interior(1, _circle(RUIN_DIR, LOOP_DEG))
	if _map._counts[2] != 0:
		return _fail("a ruína deveria ter sido toda conquistada pelo laço (restam %d de %d)" % [_map._counts[2], ruin])
	if _map._counts[1] < mine_before + ruin:
		return _fail("a civilização 1 deveria ter herdado as %d células da ruína (tinha %d, ficou com %d)" % [ruin, mine_before, _map._counts[1]])
	if _map.get_owner_at(_map._center_cache + RUIN_DIR * _map._radius) != 1:
		return _fail("o centro da ruína deveria ser da civilização 1 depois do laço")
	print("ruína: %d células intactas após a eliminação; um laço da civilização 1 as converteu (1: %d -> %d)" % [ruin, mine_before, _map._counts[1]])
	print("OK")
	quit(0)
