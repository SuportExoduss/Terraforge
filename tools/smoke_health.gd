extends SceneTree
## Teste de fumaça do 6a (vida, corte, nave): (1) o sensor corta rastro alheio; (2) corte = -2 pontos e volta à
## base; (3) o campo de força regenera; (4) base dominada = nave decola, voa, pousa longe dos polos, vida cheia,
## contagem de respawn anunciada (DD-100); (5) 8 cortes eliminam, uma única vez (R1).
## Uso: godot_console --headless --path . -s res://tools/smoke_health.gd


class FakeTrail extends RefCounted:
	var owner_id := 2
	var points: Array[Vector3] = []
	var cuts: Array[int] = []

	func cut(attacker_id: int) -> void:
		cuts.append(attacker_id)


var _bus: Node
var _runner: Node
var _base_pos := Vector3.ZERO
var _fake := FakeTrail.new()
var _time := 0.0
var _phase := 0
var _started := false
var _health_log: Array[int] = []
var _eliminated := 0
var _fallen := 0
var _landed_at := Vector3.INF
var _countdown_seen: Array[int] = []


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	_runner = main_scene.get_node("Runner")
	_bus = root.get_node("EventBus")
	_bus.match_started.connect(func(): _started = true)
	_bus.health_changed.connect(func(id, pts, _max): if id == 1: _health_log.append(pts))
	_bus.civilization_eliminated.connect(func(id): if id == 1: _eliminated += 1)
	_bus.base_fallen.connect(func(id, _by): if id == 1: _fallen += 1)
	_bus.respawn_countdown.connect(func(id, s): if id == 1: _countdown_seen.append(s))
	# A abertura também emite base_relocated; só o 2º pouso (realocação) interessa à fase 4.
	_bus.base_relocated.connect(func(id, pos): if id == 1 and _phase == 4: _landed_at = pos)


func _fail(msg: String) -> bool:
	print("FALHOU: ", msg)
	quit(1)
	return true


func _process(delta: float) -> bool:
	_time += delta
	if _time > 40.0:
		return _fail("tempo esgotado na fase %d" % _phase)
	var health: Node = _runner.get_node("Health")
	match _phase:
		0:  # espera o GO! (descida pulada, nave pousa, partida começa)
			if _started:
				_base_pos = root.get_node("Services").home_bases[1]["position"]
				print("fase0: GO! base em ", _base_pos, " vida=", health.points)
				if health.points != 16 or _health_log.is_empty() or _health_log[0] != 16:
					return _fail("vida inicial deveria ser 16 e publicada")
				var p: Vector3 = _runner.global_position
				var f: Vector3 = _runner.forward
				for k in [-2.0, 0.0, 2.0, 4.0, 6.0, 8.0]:
					_fake.points.append(p + f * k)
				root.get_node("Services").register_trail(_fake)
				_phase = 1
				_time = 0.0
		1:  # sensor: o corredor atravessa rastro alheio
			if _time > 0.6:
				root.get_node("Services").unregister_trail(_fake)
				print("fase1: cortes no rastro falso=", _fake.cuts)
				if _fake.cuts.is_empty() or _fake.cuts[0] != 1:
					return _fail("o sensor não cortou o rastro alheio")
				# corte sofrido: leva o corredor longe da base e dispara o corte contra ele
				_runner.teleport_to(_base_pos + _runner.forward * 40.0)
				_bus.trail_cut.emit(1, 2)
				var dist: float = _runner.global_position.distance_to(_base_pos)
				print("fase2: vida=%d  distância da base=%.1f" % [health.points, dist])
				if health.points != 14 or dist > 3.0:
					return _fail("corte deveria tirar 2 pontos e devolver à base")
				_runner.set_process(false)   # parado dentro do domo (senão ele corre para fora e não regenera)
				_phase = 3
				_time = 0.0
		3:  # regeneração (R3): 1 ponto a cada 1,5 s dentro do campo
			if _time > 1.7:
				print("fase3: vida=", health.points)
				if health.points != 15:
					return _fail("o campo de força deveria regenerar 1 ponto em 1,5 s")
				# DD-100: um adversário toma o chão da base
				var map: Node = root.get_node("Main/Territory")
				map.claim_cap(2, (_base_pos - Vector3.ZERO).normalized(), 0.5)
				_phase = 4
				_time = 0.0
		4:  # nave: vistoria (0,5 s) + decolagem (0,2 s) + voo (4 s) + pouso
			if _landed_at != Vector3.INF:
				var planet: Node = root.get_node("Services").planet
				var sin_lat: float = absf((_landed_at - planet.center).normalized().y)
				var home: Node = root.get_node("Main/HomeBase")
				var owned: bool = root.get_node("Services").territory.is_owned_by(1, _landed_at)
				var dist: float = _runner.global_position.distance_to(_landed_at)
				print("fase4: caiu=%d pousou a %.0f u da base antiga | sin_lat=%.2f | estado=%d | vida=%d | contagem=%s | do_jogador=%s | corredor a %.1f u" % [
						_fallen, _landed_at.distance_to(_base_pos), sin_lat, home.state, health.points, _countdown_seen, owned, dist])
				if _fallen != 1 or _landed_at.distance_to(_base_pos) < 20.0 or sin_lat > 0.8 + 0.01:
					return _fail("a base deveria cair 1x e a nave pousar longe da antiga, fora dos polos")
				if health.points != 16 or not owned or dist > 3.0:
					return _fail("pouso deveria dar vida cheia, território e o corredor ao lado da nave")
				if not _countdown_seen.has(0) or not _countdown_seen.has(3):
					return _fail("contagem de respawn não anunciou 3..0")
				_phase = 5
				_time = 0.0
		5:  # R1: 8 cortes x 2 pontos = 16 -> eliminada, uma vez só
			for i in 9:
				_bus.trail_cut.emit(1, 2)
			print("fase5: vida=%d eliminações=%d" % [health.points, _eliminated])
			if health.points != 0 or _eliminated != 1:
				return _fail("zerar a vida deveria eliminar exatamente uma vez")
			print("OK")
			quit(0)
	return false
