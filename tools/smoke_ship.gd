extends SceneTree
## Teste de fumaça: a nave NÃO pode inverter de lado (180°) entre quadros, nem na descida de abertura (DD-096)
## nem no voo de realocação (DD-100). Antes da correção, _place lia -Z e gravava com +Z = frente: virava a cada quadro.
## Uso: godot_console --headless --path . -s res://tools/smoke_ship.gd

var _match: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _sample(home: Node3D, wanted_state: int, frames: int) -> int:
	var flips := 0
	var last: Vector3 = home.global_transform.basis.z
	for i in frames:
		await process_frame
		if home.state != wanted_state:
			break
		var z: Vector3 = home.global_transform.basis.z
		if z.dot(last) < 0.0:
			flips += 1
		last = z
	return flips


func _run() -> void:
	for i in 30:
		await process_frame
	var home: Node3D = get_nodes_in_group("home_base")[0]
	var flips: int = await _sample(home, 0, 40)   # 0 = OPENING_DESCENT
	if flips > 0:
		print("FALHOU: a nave inverteu de lado %d vezes na descida" % flips)
		quit(1)
		return
	home.relocation_delay_seconds = 0.0
	home._clock = 0.0
	home.state = 2   # COUNTDOWN -> decola no próximo quadro
	await process_frame
	await process_frame
	flips = await _sample(home, 3, 40)   # 3 = FLYING
	if flips > 0:
		print("FALHOU: a nave inverteu de lado %d vezes no voo" % flips)
		quit(1)
		return
	print("OK")
	quit(0)
