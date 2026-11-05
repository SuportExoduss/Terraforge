extends SceneTree
## Mede o custo de desenhar o planeta pintado (vsync desligado; exige janela, sem --headless).
## Critério DD-124: 45+ FPS no notebook. Mede 3 s de câmera parada sobre o território do jogador.
## Uso: godot_console --path . -s res://tools/bench_render.gd

const WARMUP := 1.5
const MEASURE := 3.0

var _main: Node
var _t := 0.0
var _frames := 0
var _worst := 0.0
var _ready_for_bench := false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("HomeBase").skip_ceremony()   # sem a descida de abertura (7 s)
	root.add_child(_main)


func _process(delta: float) -> bool:
	var map: Node = _main.get_node("Territory")
	if not _ready_for_bench:
		if map._counts[1] == 0:
			return false
		_ready_for_bench = true
		var cam: Camera3D = _main.get_node("Camera")
		cam.set_process(false)
		map.claim_cap(1, Vector3.UP, 0.35)
		map.claim_cap(2, Vector3(1, 0.2, 0.1).normalized(), 0.3)
		_main.get_node("Planet/Painter").paint_all_now()
		cam.global_position = Vector3(0.0, 1.0, 0.45).normalized() * 175.0
		cam.look_at(Vector3(0, 100, 0), Vector3.UP)
		return false
	_t += delta
	if _t > WARMUP:
		_frames += 1
		_worst = maxf(_worst, delta)
	if _t > WARMUP + MEASURE:
		var avg := MEASURE / _frames
		print("quadros=%d  média=%.2f ms (%.0f FPS)  pior=%.2f ms" % [_frames, avg * 1000.0, 1.0 / avg, _worst * 1000.0])
		print("OK" if 1.0 / avg >= 45.0 else "ABAIXO DE 45 FPS")
		quit()
	return false
