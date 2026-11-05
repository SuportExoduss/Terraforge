extends SceneTree
## Tira fotos do planeta pintado (exige janela, sem --headless) e confere a elevação do bioma (DD-121).
## Uso: godot_console --path . -s res://tools/shot_planet.gd -- <pasta de saída>
## Sai com código 1 se a elevação estiver errada; as fotos são para o olho humano.

var _main: Node
var _frame := 0
var _shots: Array = []
var _out := ""
var _failed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	var map: Node = _main.get_node("Territory")
	var planet: Node3D = _main.get_node("Planet")
	var painter = planet.get_node("Painter")
	if _shots.is_empty():
		if map._counts[1] == 0:   # espera a base do jogador reivindicar a calota
			return _frame > 600 and _fail("a base não reivindicou a calota")
		var cam: Camera3D = _main.get_node("Camera")
		cam.set_process(false)
		# três impérios grandes: jogador (piso Velho Oeste), civ 2 e civ 4 (cores chapadas)
		map.claim_cap(1, Vector3.UP, 0.35)
		map.claim_cap(2, Vector3(1, 0.2, 0.1).normalized(), 0.3)
		map.claim_cap(4, Vector3(-0.6, -0.5, 0.6).normalized(), 0.3)
		var t0 := Time.get_ticks_usec()
		var cells: int = painter.pending_cells()
		painter.paint_all_now()
		print("pintou %d células em %.1f ms (%.1f us/célula)" % [cells, (Time.get_ticks_usec() - t0) / 1000.0, float(Time.get_ticks_usec() - t0) / cells])
		_check_elevation(painter)
		_shots = [
			["longe", Vector3(0.7, 0.55, 0.45).normalized() * 330.0, Vector3.ZERO],
			["civ2", Vector3(1, 0.2, 0.1).normalized() * 180.0, Vector3.ZERO],
			["jogador_perto", Vector3(0.0, 1.0, 0.45).normalized() * 175.0, Vector3(0, 100, 0)],
			["borda", Vector3(0.38, 0.93, 0.0).normalized() * 125.0, Vector3(0.28, 0.96, 0.0).normalized() * 100.0],
		]
		_frame = 0
		return false
	var i := _frame / 6 - 1
	if _frame % 6 == 0 and i >= 0 and i < _shots.size():
		_save(_shots[i])
	if _frame % 6 == 3 and _frame / 6 < _shots.size():
		var s: Array = _shots[_frame / 6]
		var cam: Camera3D = _main.get_node("Camera")
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP if absf(s[1].normalized().y) < 0.99 else Vector3.RIGHT)
	if _frame / 6 > _shots.size():
		print("OK" if not _failed else "FALHOU")
		quit(1 if _failed else 0)
	return false


func _save(shot: Array) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, shot[0]]
	print("foto ", path, " ", img.get_size(), " erro=", img.save_png(path), "  fps=", Engine.get_frames_per_second())


func _check_elevation(painter) -> void:
	var inside: float = painter.get_elevation_at(Vector3.UP)
	var outside: float = painter.get_elevation_at(Vector3(0, -1, 0))
	var edge: float = painter.get_elevation_at(Vector3(sin(0.35), cos(0.35), 0))
	print("elevação: miolo=%.3f  antípoda=%.3f  borda=%.3f" % [inside, outside, edge])
	if absf(inside - 0.6) > 0.01:
		_fail("elevação do miolo deveria ser 0,6")
	if outside != 0.0:
		_fail("fora do território a elevação deveria ser 0")
	if not (edge > 0.0 and edge < 0.6):
		_fail("a borda deveria estar em rampa")


func _fail(msg: String) -> bool:
	print("  FALHOU: ", msg)
	_failed = true
	return true
