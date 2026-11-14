extends SceneTree
## Teste de fumaça do Passo 97 (SYS-001, critério "funcionamento próximo aos polos"): o MESMO laço circular (12° de raio,
## ~21 u) fechado no polo norte, no polo sul e em quatro pontos do equador conquista a mesma área (±20%), contém o centro
## e deixa o lado oposto do planeta em paz. A grade é de baldes 3D (sem latitude/longitude), então os polos não podem ser especiais.
## Uso: godot_console --headless --path . -s res://tools/smoke_polar_loops.gd

const RADIUS_DEG := 12.0
const POINTS := 48
const CENTERS := [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]

var _map: Node       # sem tipo: referenciar TerritoryMap aqui compilaria antes dos autoloads existirem
var _time := 0.0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	_map = root.get_node("Main/Territory")


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	elif _map._counts[1] > 0:   # a base já reivindicou a calota
		_verify()
	return false


# Um círculo de `deg` graus em volta de `c`, em pontos do mundo (o raio e o centro do mapa).
func _circle(c: Vector3, deg: float) -> PackedVector3Array:
	var u := c.cross(Vector3.RIGHT if absf(c.x) < 0.9 else Vector3.UP).normalized()
	var v := c.cross(u)
	var pts := PackedVector3Array()
	for i in POINTS:
		var a := TAU * i / POINTS
		var dir := c * cos(deg_to_rad(deg)) + (u * cos(a) + v * sin(a)) * sin(deg_to_rad(deg))
		pts.append(_map._center_cache + dir.normalized() * _map._radius)
	return pts


func _free_around(c: Vector3, deg: float) -> bool:
	var min_dot := cos(deg_to_rad(deg + 5.0))
	for cell in _map.cell_count:
		if _map._owners[cell] != 0 and _map._dirs[cell].dot(c) >= min_dot:
			return false
	return true


func _verify() -> void:
	var expected: float = _map.cell_count * (1.0 - cos(deg_to_rad(RADIUS_DEG + 1.0))) / 2.0   # calota + meia espessura da cerca
	var gains: Array[int] = []
	var ok := true
	var polar := 0
	for c in CENTERS:
		if not _free_around(c, RADIUS_DEG):
			print("  (pulou %s: a base está por perto)" % c)
			continue
		var before: int = _map._counts[1]
		_map.claim_loop_interior(1, _circle(c, RADIUS_DEG))
		var gain: int = _map._counts[1] - before
		gains.append(gain)
		if absf(c.y) > 0.9:
			polar += 1
		var center_owner: int = _map.get_owner_at(_map._center_cache + c * _map._radius)
		var far_owner: int = _map.get_owner_at(_map._center_cache - c * _map._radius)
		print("centro %s: +%d células (esperado ~%d)  dono do centro=%d  dono do lado oposto=%d" % [c, gain, expected, center_owner, far_owner])
		if center_owner != 1: ok = _no("o centro do laço não virou do jogador")
		if far_owner == 1 and _free_around(-c, RADIUS_DEG): ok = _no("o lado oposto do planeta foi conquistado")
		if gain < expected * 0.8 or gain > expected * 1.4: ok = _no("área fora do esperado (%d)" % gain)
	if polar < 1: ok = _no("nenhum polo livre para o laço pequeno")
	# O polo norte tem a base: um laço maior (30°) em volta dos DOIS polos, sem buracos e com a mesma área final.
	var caps: Array[int] = []
	for c in [Vector3.UP, Vector3.DOWN]:
		_map.claim_loop_interior(1, _circle(c, 30.0))
		var inside := 0
		var holes := 0
		for cell in _map.cell_count:
			if _map._dirs[cell].dot(c) >= cos(deg_to_rad(28.0)):
				inside += 1
				if _map._owners[cell] != 1: holes += 1
		caps.append(inside - holes)
		print("laço de 30° em %s: %d células dentro, %d buracos" % [c, inside, holes])
		if holes > 0: ok = _no("buracos dentro do laço no polo %s" % c)
	if caps[0] != caps[1]: print("  (calotas de 28° com %d e %d células: a grade é de Fibonacci, pequena diferença é normal)" % [caps[0], caps[1]])
	if absi(caps[0] - caps[1]) > caps[0] * 0.05: ok = _no("as duas calotas diferem demais")
	if gains.size() < 4: ok = _no("poucos laços testados (%d)" % gains.size())
	elif float(gains.max()) > gains.min() * 1.2: ok = _no("a área depende de onde o laço fecha (%d a %d)" % [gains.min(), gains.max()])
	print("OK (%d laços, de %d a %d células cada)" % [gains.size(), gains.min(), gains.max()] if ok else "FALHOU")
	quit(0 if ok else 1)


func _no(msg: String) -> bool:
	print("  FALHOU: ", msg)
	return false
