extends SceneTree
## Teste de fumaça: carrega a cena principal, confere que o corredor anda colado na superfície e
## que "direita" curva para a direita (~90° em 0,5 s a 180°/s).
## Uso: godot_console --headless --path . -s res://tools/smoke_runner.gd

var _runner: Node3D
var _planet: Node3D
var _start := Vector3.ZERO
var _frames := 0
var _time := 0.0
var _steer_start := -1.0
var _fwd0 := Vector3.ZERO


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())
	_runner = root.get_node("Main/Runner")
	_planet = root.get_node("Main/Planet")


func _process(delta: float) -> bool:
	_frames += 1
	_time += delta
	if _frames == 60:
		_start = _runner.global_position
	if _frames == 300 and _steer_start < 0.0:
		var r := (_runner.global_position - _planet.global_position).length()
		var moved := _runner.global_position.distance_to(_start)
		print("surface_ready=%s  dist_centro=%.2f  andou=%.2f" % [_planet.surface_ready, r, moved])
		if not (_planet.surface_ready and moved > 5.0 and r > 90.0 and r < 115.0):
			print("FALHOU: corredor não anda ou não está colado")
			quit(1)
		_steer_start = _time
		_fwd0 = _runner.forward
		Input.action_press("ui_right")
	elif _steer_start >= 0.0 and _time - _steer_start >= 0.5:
		Input.action_release("ui_right")
		var up := (_runner.global_position - _planet.global_position).normalized()
		var angle := rad_to_deg(_fwd0.signed_angle_to(_runner.forward, up))
		print("giro com 'direita' por 0.5 s: %.1f graus (esperado ~ -90; negativo = horário visto de cima)" % angle)
		var ok := angle < -70.0 and angle > -110.0
		print("OK" if ok else "FALHOU: direção/velocidade de giro errada")
		quit(0 if ok else 1)
	return false
