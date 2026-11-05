extends SceneTree
## Teste de fumaça: carrega a cena principal, roda ~4 s de jogo simulado e confere que o corredor
## anda e continua colado na superfície. Uso: godot_console --headless --path . -s res://tools/smoke_runner.gd

var _runner: Node3D
var _planet: Node3D
var _start := Vector3.ZERO
var _frames := 0


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	_runner = root.get_node("Main/Runner")
	_planet = root.get_node("Main/Planet")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 60:
		_start = _runner.global_position
	if _frames == 300:
		var r := (_runner.global_position - _planet.global_position).length()
		var moved := _runner.global_position.distance_to(_start)
		print("surface_ready=%s  dist_centro=%.2f  andou=%.2f" % [_planet.surface_ready, r, moved])
		var ok: bool = _planet.surface_ready and moved > 5.0 and r > 90.0 and r < 115.0
		print("OK" if ok else "FALHOU: corredor não anda ou não está colado")
		quit(0 if ok else 1)
	return false
