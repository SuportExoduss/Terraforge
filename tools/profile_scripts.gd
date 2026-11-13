extends SceneTree
## Perfil de CPU dos scripts da partida: assume o `_process` e o `_physics_process` de cada nó (que o Godot deixa de chamar)
## e chama cada um cronometrado. Mostra quem gasta mais no total e quem produz os piores quadros. Sem janela, sem GPU:
## só o custo dos scripts. O resultado vai para ARQUIVO (print custa 10-30 ms/linha).
## Uso: godot_console --headless --path . --fixed-fps 60 -s res://tools/profile_scripts.gd   (log em D:/Terraforge_Godot/.profile_scripts.log)
## Variável: PROFILE_SECONDS (segundos de jogo, padrão 25).

var _file: FileAccess
var _match: Node
var _seconds := 25.0
var _frames := 0
var _taken: Array = []        # nós assumidos (na ordem da árvore)
var _total := {}              # "caminho:função" -> [µs somados, pior µs, chamadas]
var _worst_frames: Array = [] # [µs do quadro, nome do mais caro]


func _initialize() -> void:
	_file = FileAccess.open("D:/Terraforge_Godot/.profile_scripts.log", FileAccess.WRITE)
	if OS.get_environment("PROFILE_SECONDS") != "":
		_seconds = float(OS.get_environment("PROFILE_SECONDS"))
	load("res://scripts/core/profile.gd").path = "user://profile_bench.json"
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").bot_count = 5
	_match.get_node("MatchTimer").duration_seconds = _seconds + 60.0
	root.add_child(_match)
	node_added.connect(func(n): _adopt.call_deferred(n))
	for n in _match.find_children("*", "", true, false):
		_adopt(n)
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == 1:
			var brain: Node = load("res://scripts/ai/bot_steering.gd").new()
			brain.min_sortie_distance = 26.0
			brain.max_sortie_distance = 60.0
			brain.max_exposure_seconds = 20.0
			r.use_steering(brain)


func _adopt(n: Node) -> void:
	if not is_instance_valid(n) or n == _match or _taken.has(n):
		return
	var script := n.get_script() as Script
	if script == null:
		return
	if n.is_processing() or n.is_physics_processing():
		n.set_process(false)
		n.set_physics_process(false)
		_taken.append(n)


func _process(delta: float) -> bool:
	_frames += 1
	var frame_us := 0
	var worst_name := ""
	var worst_us := 0
	for n in _taken:
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		for fn in ["_process", "_physics_process"]:
			if not n.has_method(fn):
				continue
			var t := Time.get_ticks_usec()
			n.call(fn, delta)
			var us := Time.get_ticks_usec() - t
			var key := "%s:%s" % [str(n.get_path()).trim_prefix("/root/Match/"), fn]
			var rec: Array = _total.get(key, [0, 0, 0])
			rec[0] += us
			rec[1] = maxi(rec[1], us)
			rec[2] += 1
			_total[key] = rec
			frame_us += us
			if us > worst_us:
				worst_us = us
				worst_name = key
	_worst_frames.append([frame_us, worst_name])
	if _frames >= _seconds * 60.0:
		_report()
		quit()
	return false


func _say(text: String) -> void:
	_file.store_line(text)
	_file.flush()


func _report() -> void:
	var rows: Array = []
	var sum := 0
	for k in _total:
		rows.append([k, _total[k][0], _total[k][1], _total[k][2]])
		sum += _total[k][0]
	_say("%d quadros · %d nós assumidos · script total %.1f ms/quadro" % [_frames, _taken.size(), sum / 1000.0 / _frames])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	_say("--- por custo total (ms/quadro · pior chamada ms)")
	for r in rows.slice(0, 14):
		_say("  %6.2f  pior %6.1f  %s" % [r[1] / 1000.0 / _frames, r[2] / 1000.0, r[0]])
	rows.sort_custom(func(a, b): return a[2] > b[2])
	_say("--- pior chamada isolada (ms)")
	for r in rows.slice(0, 10):
		_say("  pior %6.1f  média %5.2f  %s" % [r[2] / 1000.0, r[1] / 1000.0 / maxi(r[3], 1), r[0]])
	_worst_frames.sort_custom(func(a, b): return a[0] > b[0])
	_say("--- piores quadros de script (ms · o mais caro dentro dele)")
	for f in _worst_frames.slice(0, 12):
		_say("  %6.1f  %s" % [f[0] / 1000.0, f[1]])
	var over := 0
	for f in _worst_frames:
		if f[0] > 12000:
			over += 1
	_say("quadros de script acima de 12 ms: %d de %d" % [over, _frames])
	_say("FIM")
