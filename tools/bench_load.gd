extends SceneTree
## Mede (1) a carga da partida em segundo plano, (2) o custo de instanciar e (3) as travadas dos primeiros segundos de jogo
## com o jogador como bot de conquista. Exige janela (sem --headless). O resultado vai para ARQUIVO (print custa 10-30 ms/linha).
## Uso: godot_console --path . -s res://tools/bench_load.gd   (log em D:/Terraforge_Godot/.bench_load.log)
## Variável: BENCH_SECONDS (duração do jogo medido, padrão 25).

const PATH := "res://scenes/match.tscn"
const HITCH_MS := 40.0

var _file: FileAccess
var _phase := 0               # 0 carregando · 1 jogando · 2 pronto
var _t0 := 0
var _last := 0
var _stamp := 0
var _frames: Array[float] = []
var _hitches: Array = []      # [ms, segundos desde o início da fase]
var _match: Node
var _seconds := 25.0
var _ready_last := 0
var _mem := 0
var _ready_cost: Array = []   # [µs, caminho]: quanto custou o _ready de cada nó (a ordem é de baixo para cima)


func _initialize() -> void:
	_file = FileAccess.open("D:/Terraforge_Godot/.bench_load.log", FileAccess.WRITE)
	if OS.get_environment("BENCH_SECONDS") != "":
		_seconds = float(OS.get_environment("BENCH_SECONDS"))
	load("res://scripts/core/profile.gd").path = "user://profile_bench.json"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_say("memória no início: %d MB" % (OS.get_static_memory_usage() / 1048576))
	ResourceLoader.load_threaded_request(PATH)
	# o que o menu faz ao abrir (Passos 89/90/92); load() em tempo de execução porque um -s é compilado antes dos autoloads
	load("res://scripts/audio/sound_bank.gd").warm()
	load("res://scripts/core/model_cache.gd").prefetch()
	load("res://scripts/world/territory_map.gd").warm()   # Passo 92
	_t0 = Time.get_ticks_usec()
	_last = _t0


func _say(text: String) -> void:
	_file.store_line(text)
	_file.flush()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	_frames.append(ms)
	if ms > HITCH_MS:
		# processo/física = tempo de script+motor medido pelo próprio Godot no quadro anterior; o resto é GPU, carga síncrona ou outro processo
		_hitches.append([ms, (now - _stamp) / 1.0e6, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, (OS.get_static_memory_usage() - _mem) / 1048576.0])
	_mem = OS.get_static_memory_usage()
	if _phase == 0:
		if ResourceLoader.load_threaded_get_status(PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
		_say("carga em segundo plano: %.1f s (quadros: %d, pior %.0f ms)" % [(now - _t0) / 1.0e6, _frames.size(), _worst()])
		var scene := ResourceLoader.load_threaded_get(PATH) as PackedScene
		var t := Time.get_ticks_usec()
		_match = scene.instantiate()
		_match.get_node("MatchSetup").bot_count = 5
		_match.get_node("MatchTimer").duration_seconds = _seconds + 30.0
		_say("instanciar: %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
		t = Time.get_ticks_usec()
		_ready_last = t
		node_added.connect(_watch)
		root.add_child(_match)
		node_added.disconnect(_watch)
		_say("add_child (os _ready): %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
		_ready_cost.sort_custom(func(a, b): return a[0] > b[0])
		for c in _ready_cost.slice(0, 12):
			_say("  _ready %6.0f ms  %s" % [c[0] / 1000.0, c[1]])
		_say("memória após carregar: %d MB" % (OS.get_static_memory_usage() / 1048576))
		_frames.clear()
		_hitches.clear()
		_stamp = Time.get_ticks_usec()
		_phase = 1
		_take_the_wheel.call_deferred()
	elif _phase == 1 and (now - _stamp) / 1.0e6 > _seconds:
		_frames.sort()
		var n := _frames.size()
		_say("jogo: %d quadros em %.0f s · média %.1f ms · p95 %.1f ms · p99 %.1f ms · pior %.0f ms" % [n, _seconds, _seconds * 1000.0 / n, _frames[int(n * 0.95)], _frames[int(n * 0.99)], _frames[n - 1]])
		_say("travadas > %d ms: %d" % [HITCH_MS, _hitches.size()])
		for h in _hitches.slice(0, 25):
			_say("  %.0f ms em t=%.2f s  (processo %.0f ms · física %.0f ms · memória %+.1f MB)" % h)
		_say("memória no fim: %d MB" % (OS.get_static_memory_usage() / 1048576))
		_say("FIM")
		quit()
	return false


func _watch(node: Node) -> void:
	node.ready.connect(func():
		var now := Time.get_ticks_usec()
		_ready_cost.append([now - _ready_last, str(node.get_path())])
		_ready_last = now)


func _worst() -> float:
	var w := 0.0
	for f in _frames:
		w = maxf(w, f)
	return w


func _take_the_wheel() -> void:
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == 1:
			var brain: Node = load("res://scripts/ai/bot_steering.gd").new()
			brain.min_sortie_distance = 26.0
			brain.max_sortie_distance = 60.0
			brain.max_exposure_seconds = 20.0
			r.use_steering(brain)
