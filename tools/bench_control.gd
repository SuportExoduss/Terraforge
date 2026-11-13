extends SceneTree
## CONTROLE do bench_load: uma cena com UM cubo, janela aberta, 20 s, vsync desligado; conta quadros > 40 ms.
## Se a cena vazia também trava, a travada vem do computador (outro jogo/editor aberto dividindo CPU e a UHD 620), não do projeto.
## Uso: godot_console --path . -s res://tools/bench_control.gd   (resultado em D:/Terraforge_Godot/.bench_control.log)

const HITCH_MS := 40.0
const SECONDS := 20.0

var _last := 0
var _t0 := 0
var _frames := 0
var _hitches: Array[float] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	root.add_child(cube)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 3.0)
	root.add_child(camera)
	_t0 = Time.get_ticks_usec()
	_last = _t0


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	_frames += 1
	if ms > HITCH_MS and _frames > 30:   # os primeiros quadros pagam a abertura da janela
		_hitches.append(snappedf(ms, 0.1))
	if now - _t0 > SECONDS * 1.0e6:
		var file := FileAccess.open("D:/Terraforge_Godot/.bench_control.log", FileAccess.WRITE)
		file.store_line("cena vazia: %d quadros em %.0f s · travadas > %.0f ms: %d %s" % [_frames, SECONDS, HITCH_MS, _hitches.size(), str(_hitches)])
		file.close()
		quit()
	return false
