extends SceneTree
## Teste de fumaça do Passo 98 (SYS-001, critérios "áreas pequenas e grandes" e "ausência de perdas de território por erro de cálculo").
## Laços circulares de 4° a 100° de raio fecham a MENOR das duas bandas em que o círculo divide o planeta (o laço de 100° em volta de
## um ponto é, visto do outro lado, um laço de 80°): sem buracos dentro, nada conquistado fora, nenhuma célula do jogador perdida
## e o placar (`_counts`) igual à contagem real do mapa.
## Uso: godot_console --headless --path . -s res://tools/smoke_loop_sizes.gd

const POINTS := 96
const CASES := [4.0, 25.0, 45.0, 70.0, 90.0, 100.0]   # raio angular do laço (90° = círculo máximo: qualquer metade serve)
const CENTER := Vector3.RIGHT

var _map: Node       # sem tipo: referenciar TerritoryMap aqui compilaria antes dos autoloads existirem
var _time := 0.0
var _initial: PackedByteArray


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


func _circle(c: Vector3, deg: float) -> PackedVector3Array:
	var u := c.cross(Vector3.UP).normalized()
	var v := c.cross(u)
	var pts := PackedVector3Array()
	for i in POINTS:
		var a := TAU * i / POINTS
		var dir := c * cos(deg_to_rad(deg)) + (u * cos(a) + v * sin(a)) * sin(deg_to_rad(deg))
		pts.append(_map._center_cache + dir.normalized() * _map._radius)
	return pts


# Volta o mapa ao começo da partida (só a calota da base) e refaz o placar.
func _reset() -> void:
	_map._owners = _initial.duplicate()
	_map._counts.fill(0)
	for cell in _map.cell_count:
		if _initial[cell] != 0:
			_map._counts[_initial[cell]] += 1


func _verify() -> void:
	_initial = _map.owners_snapshot()
	var ok := true
	for deg in CASES:
		_reset()
		var t0 := Time.get_ticks_usec()
		_map.claim_loop_interior(1, _circle(CENTER, deg))
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var real := 0
		var lost := 0
		var gained := 0
		var stray := 0
		var other := 0
		var small := minf(deg, 180.0 - deg)                      # raio da banda menor
		var band := CENTER if deg <= 90.0 else -CENTER           # centro da banda menor
		var inside := cos(deg_to_rad(small - 3.0))
		var outside := cos(deg_to_rad(small + 5.0))
		var holes := 0
		for cell in _map.cell_count:
			var now: int = _map._owners[cell]
			var d: float = _map._dirs[cell].dot(band)
			if now == 1: real += 1
			elif now != 0: other += 1
			if _initial[cell] == 1 and now != 1: lost += 1
			if _initial[cell] == 0 and now == 1:
				gained += 1
				if d < outside: stray += 1
			if d >= inside and now != 1 and deg != 90.0: holes += 1
		print("laço de %5.1f°: +%5d células em %5.1f ms  (sem dono dentro=%d, fora do esperado=%d, perdidas=%d)" % [deg, gained, ms, holes, stray, lost])
		if lost > 0: ok = _no("%d células do jogador sumiram" % lost)
		if other > 0: ok = _no("%d células de outro dono apareceram" % other)
		if real != _map._counts[1]: ok = _no("placar %d ≠ contagem real %d" % [_map._counts[1], real])
		if deg != 90.0:
			if holes > 0: ok = _no("%d células sem dono dentro do laço" % holes)
			if stray > 0: ok = _no("%d células conquistadas fora do laço" % stray)
			if gained < 1: ok = _no("o laço não conquistou nada")
		else:
			# círculo máximo: a banda é qualquer metade; confere só que nada de absurdo (mais que 3/5 do planeta) aconteceu
			if gained > _map.cell_count * 0.6: ok = _no("conquistou mais que meio planeta (%d)" % gained)
	_reset()
	print("OK (%d tamanhos de laço, de 4° a 100°)" % CASES.size() if ok else "FALHOU")
	quit(0 if ok else 1)


func _no(msg: String) -> bool:
	print("  FALHOU: ", msg)
	return false
