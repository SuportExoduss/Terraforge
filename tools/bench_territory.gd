extends SceneTree
## Teste + benchmark do TerritoryMap: calota, conquista por circuito, conversão de inimigo
## cercado, amputação DD-102, selagem de bolsões, e tempos de cada operação.
## Uso: godot_console --headless --path . -s res://tools/bench_territory.gd

const R := 100.0

var _map: Node        # sem tipo: referenciar TerritoryMap aqui compilaria antes dos autoloads existirem
var _services: Node
var _failed := 0
var _done := false


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()   # sem a descida de abertura (7 s)
	root.add_child(main_scene)
	_map = root.get_node("Main/Territory")
	_services = root.get_node("Services")


func _check(ok: bool, msg: String) -> void:
	print(("  ok     " if ok else "  FALHOU ") + msg)
	if not ok:
		_failed += 1


func _cells(id: int) -> int:
	return _map._counts[id]


func _at(dir: Vector3) -> int:
	return _map.get_owner_at(dir.normalized() * R)


# Círculo de raio angular `theta` em volta de `dir`, com pontos a ~1,5 unidade um do outro (como o rastro).
func _circle(dir: Vector3, theta: float) -> PackedVector3Array:
	dir = dir.normalized()
	var u := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var v := dir.cross(u)
	var n := maxi(3, ceili(TAU * R * sin(theta) / 1.5))
	var pts := PackedVector3Array()
	for i in n:
		var phi := TAU * i / n
		pts.append((dir * cos(theta) + (u * cos(phi) + v * sin(phi)) * sin(theta)) * (R + 0.15))
	return pts


func _timed_loop(id: int, dir: Vector3, theta_deg: float) -> float:
	var pts := _circle(dir, deg_to_rad(theta_deg))
	var t0 := Time.get_ticks_usec()
	_map.claim_loop_interior(id, pts)
	return (Time.get_ticks_usec() - t0) / 1000.0


func _process(_delta: float) -> bool:
	if _done or _cells(1) == 0:   # espera a base do jogador reivindicar a calota
		return false
	_done = true
	var n: int = _map.cell_count

	print("== grade ==")
	print("  construção: %.0f ms" % _map.build_msec)
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		_map.is_owned_by(1, Vector3(0.0, 101.0, 0.0))
		_map.is_owned_by(1, Vector3(60.0, -80.0, 10.0))
	print("  is_owned_by: %.1f us/chamada" % ((Time.get_ticks_usec() - t0) / 2000.0))

	print("== calota do jogador ==")
	var cap_cells := _cells(1)
	_check(cap_cells >= 15 and cap_cells <= 50, "calota tem ~28 células (veio %d)" % cap_cells)
	_check(_map.is_owned_by(1, Vector3(0.0, 100.0, 0.0)), "base é do jogador")
	_check(not _map.is_owned_by(1, Vector3(0.0, -100.0, 0.0)), "antípoda não é")

	# Inimigo 2: calota pequena em +X com base registrada. Inimigo 3: base em -Z + fragmento em -X.
	_services.register_home_base(2, Vector3.RIGHT * R, 7.5)
	_map.claim_cap(2, Vector3.RIGHT, deg_to_rad(5.0))
	_services.register_home_base(3, Vector3.BACK * -R, 7.5)
	_map.claim_cap(3, Vector3.BACK * -1.0, deg_to_rad(4.0))
	_map.claim_cap(3, Vector3.LEFT, deg_to_rad(15.0))
	var enemy3_total := _cells(3)

	print("== circuito livre (30 graus em +Z) ==")
	var before := _cells(1)
	var ms := _timed_loop(1, Vector3.BACK, 30.0)
	var gained := _cells(1) - before
	print("  %.1f ms, +%d células" % [ms, gained])
	_check(gained >= 1300 and gained <= 1800, "ganhou ~1500 células (esperado interior 1340 + cerca)")
	_check(_at(Vector3.BACK) == 1, "centro do circuito é do jogador")
	_check(_at(Vector3(0.0, 0.0, -1.0)) == 3, "lado oposto continua do inimigo 3")

	print("== circuito que cerca o inimigo 2 (40 graus em +X) ==")
	ms = _timed_loop(1, Vector3.RIGHT, 40.0)
	print("  %.1f ms" % ms)
	_check(_cells(2) == 0, "inimigo 2 perdeu tudo (restaram %d)" % _cells(2))
	_check(_at(Vector3.RIGHT) == 1, "base do inimigo 2 agora é do jogador")

	print("== amputação DD-102 (circuito na borda do fragmento do inimigo 3) ==")
	var c_dir := Vector3(-cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)), 0.0)
	ms = _timed_loop(1, c_dir, 30.0)
	print("  %.1f ms" % ms)
	_check(_at(Vector3.LEFT) == 1, "fragmento sem base virou do jogador")
	_check(_at(Vector3(0.0, 0.0, -1.0)) == 3, "base do inimigo 3 segue dele")
	_check(_cells(3) > 0 and _cells(3) < enemy3_total, "inimigo 3 ficou só com a calota da base (%d de %d)" % [_cells(3), enemy3_total])

	print("== bolsão livre cercado ==")
	var q := Vector3.DOWN
	var ring := PackedInt32Array()
	_map._collect_within(q, deg_to_rad(6.0) * R, ring)
	for cell in ring:
		if acos(clampf(_map._dirs[cell].dot(q), -1.0, 1.0)) > deg_to_rad(2.0):
			_map._owners[cell] = 5
			_map._counts[5] += 1
	_check(_at(q) == 0, "antes de selar, o miolo é livre")
	t0 = Time.get_ticks_usec()
	_map._seal_enclosed_free_pockets()
	print("  selagem: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	_check(_at(q) == 5, "bolsão cercado foi entregue a quem o cerca")
	_check(_at(Vector3(0.5, -0.5, 0.7)) == 0, "o oceano livre não foi tocado")

	print("== DD-100: conversão total ==")
	t0 = Time.get_ticks_usec()
	_map.convert_all_cells_of(5, 1)
	print("  convert_all: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	_check(_cells(5) == 0 and _at(q) == 1, "império do 5 herdado pelo jogador")

	var total := 0
	for id in range(1, 16):
		total += _cells(id)
	var owned := 0
	for i in n:
		if _map._owners[i] != 0:
			owned += 1
	_check(total == owned, "contadores batem com a grade (%d = %d)" % [total, owned])

	print("OK" if _failed == 0 else "FALHOU: %d verificações" % _failed)
	quit(0 if _failed == 0 else 1)
	return true
