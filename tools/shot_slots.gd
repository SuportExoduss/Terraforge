extends SceneTree
## Fotografa os slots ambientais revelados (exige janela). Põe a densidade de vegetação do Velho Oeste em 100 %
## SÓ nesta execução, para a foto ter plantas de sobra.
## Uso: godot_console --path . -s res://tools/shot_slots.gd -- <pasta de saída>

var _main: Node
var _slots: Node
var _frame := 0
var _time := 0.0
var _shots: Array = []
var _out := ""


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_slots = _main.get_node("Slots")


func _process(delta: float) -> bool:
	_frame += 1
	_time += delta
	var planet: Node3D = _main.get_node("Planet")
	var cam: Camera3D = _main.get_node("Camera")
	if _shots.is_empty():
		if not planet.surface_ready or _main.get_node("Territory")._counts[1] == 0:
			return _frame > 600
		if _frame < 10_000:   # primeira passagem: configura e espera as voltas de conferência
			_frame = 10_000
			_time = 0.0
			cam.set_process(false)
			root.get_node("Services").themes.theme_of(1).vegetation_density = 1.0
			_main.get_node("Territory").claim_cap(1, Vector3.UP, 0.9)
			planet.get_node("Painter").paint_all_now()
		if _frame < 10_130 or _time < 1.6:
			return false
		var cactus := -1
		var bush := -1
		for i in _slots._key.size():
			if _slots._key[i] >= 0 and _slots._category[i] == 0 and cactus < 0:
				cactus = i
			if _slots._key[i] >= 0 and _slots._category[i] == 1 and bush < 0:
				bush = i
		print("revelados=%d  cacto=%d arbusto=%d" % [_slots.revealed_count(1, false), cactus, bush])
		_shots = [["largo", Vector3(0.0, 1.0, 0.0) * 230.0 + Vector3(60, 0, 40), Vector3(0, 100, 0)],
				["cacto", _eye(cactus, planet), _spot(cactus, planet)],
				["arbusto", _eye(bush, planet), _spot(bush, planet)]]
		_frame = 0
		return false
	var i := _frame / 6 - 1
	if _frame % 6 == 0 and i >= 0 and i < _shots.size():
		var img := root.get_texture().get_image()
		print("foto ", _shots[i][0], " erro=", img.save_png("%s/%s.png" % [_out, _shots[i][0]]))
	if _frame % 6 == 3 and _frame / 6 < _shots.size():
		var s: Array = _shots[_frame / 6]
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
	if _frame / 6 > _shots.size():
		quit(0)
	return false


func _spot(i: int, planet: Node3D) -> Vector3:
	return planet.center + _slots._dirs[i] * (_slots._base_radius[i] + 1.5)


# Câmera 7 u acima e 12 u ao lado do pé da planta.
func _eye(i: int, planet: Node3D) -> Vector3:
	var up: Vector3 = _slots._dirs[i]
	var side := up.cross(Vector3.RIGHT).normalized()
	return _spot(i, planet) + up * 7.0 + side * 12.0
