extends SceneTree
## Teste de fumaça do Passo 36 (Cap.05 P07, DD-071/073): (1) o EventLog guarda os eventos do EventBus em ordem, com
## qualquer número de argumentos, e o anel esquece os mais antigos; (2) cada classe cai na fase certa da ordem de
## atualização (Entrada → Gameplay → Rede → Física → IA → Mundo → Interface → Áudio → Renderização), subclasses
## herdam a fase e o que não está na tabela fica de fora; (3) numa partida de verdade os dois nós existem, o log vê os
## eventos da partida e TODO módulo da tabela está na prioridade da sua fase — inclusive os que entram depois.
## Uso: godot_console --headless --path . --fixed-fps 60 -s res://tools/smoke_event_log.gd

var _bus: Node
var _failed := false


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _initialize() -> void:
	_run()


func _names(entries: Array) -> Array:
	return entries.map(func(e): return e["name"])


func _run() -> void:
	_bus = root.get_node("EventBus")

	# 1. EventLog sozinho
	var event_log: Node = load("res://scripts/core/event_log.gd").new()
	root.add_child(event_log)
	for i in 3:
		await process_frame   # o contador de quadros do motor só sai de 0 depois dos primeiros
	_check(event_log.total() == 0 and event_log.last(10).is_empty(), "log novo começa vazio")
	_bus.match_started.emit()                                                      # 0 argumentos
	_bus.match_clock_changed.emit(300)                                             # 1
	_bus.trail_cut.emit(1, 2)                                                      # 2
	_bus.radial_damage.emit(Vector3.ZERO, 1.0, 2, true, 3.0, 4, 5.0, 6)            # 8
	_check(event_log.total() == 4, "os 4 eventos (de 0, 1, 2 e 8 argumentos) devem ser registrados (%d)" % event_log.total())
	_check(_names(event_log.last(10)) == ["match_started", "match_clock_changed", "trail_cut", "radial_damage"], "ordem dos eventos: %s" % [_names(event_log.last(10))])
	_check(_names(event_log.last(2)) == ["trail_cut", "radial_damage"], "last(2) devolve os dois mais novos")
	var frames: Array = event_log.last(4).map(func(e): return e["frame"])
	_check(frames[0] > 0 and frames[3] >= frames[0], "cada evento guarda o quadro")
	_check(event_log.count_of("trail_cut") == 1 and event_log.count_of("base_fallen") == 0, "contagem por nome")
	_check(event_log.dump(2).contains("radial_damage") and event_log.dump(2).split("\n").size() == 2, "dump traz um evento por linha")
	for i in 300:
		_bus.match_clock_changed.emit(i)
	_check(event_log.total() == 304, "o total conta todos, mesmo os esquecidos (%d)" % event_log.total())
	_check(event_log.last(1000).size() == event_log.CAPACITY, "o anel guarda só os últimos %d" % event_log.CAPACITY)
	_check(event_log.count_of("match_started") == 0 and event_log.count_of("match_clock_changed") == event_log.CAPACITY, "o anel esqueceu os mais antigos")
	var newest: Array = event_log.last(1)
	_check(newest[0]["name"] == "match_clock_changed", "o mais novo continua no fim")
	event_log.free()

	# 2. Fases da ordem de atualização
	var order: Script = load("res://scripts/core/update_order.gd")
	var cases := {
		"res://scripts/gameplay/player_steering.gd": order.Phase.INPUT,
		"res://scripts/gameplay/planet_runner.gd": order.Phase.GAMEPLAY,
		"res://scripts/network/net_session.gd": order.Phase.NETWORK,
		"res://scripts/world/defender_system.gd": order.Phase.AI,
		"res://scripts/world/tsunami_event.gd": order.Phase.WORLD,   # subclasse de GlobalEvent herda a fase
		"res://scripts/ui/hud.gd": order.Phase.UI,
		"res://scripts/audio/audio_director.gd": order.Phase.AUDIO,
		"res://scripts/gameplay/runner_camera.gd": order.Phase.RENDER,
	}
	for path in cases:
		var node: Node = load(path).new()
		_check(order.phase_of(node) == cases[path], "%s deveria cair na fase %d (caiu em %d)" % [path, cases[path], order.phase_of(node)])
		node.free()
	var plain := Node.new()
	_check(order.phase_of(plain) == -1 and not order.apply_to(plain) and plain.process_priority == 0, "nó fora da tabela fica como estava")
	plain.free()
	for i in range(1, order.PRIORITY.size()):
		_check(order.PRIORITY[i] > order.PRIORITY[i - 1], "as prioridades devem crescer fase a fase")
	_check(order.PRIORITY[order.Phase.RENDER] == 100, "renderização continua em 100 (as câmeras já usavam)")

	# 3. Numa partida de verdade
	var match_scene: Node = load("res://scenes/match.tscn").instantiate()
	match_scene.get_node("MatchSetup").skip_ceremony = true
	match_scene.get_node("Meteors").min_seconds_between = 100000.0
	match_scene.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(match_scene)
	await _bus.match_started
	for i in 30:
		await process_frame
	var match_log: Node = match_scene.get_node_or_null("EventLog")
	_check(match_log != null and match_scene.get_node_or_null("Order") != null, "a partida deve ter EventLog e Order")
	_check(match_log.count_of("match_started") == 1, "o log da partida viu match_started")
	_check(match_log.count_of("match_state_changed") >= 1, "o log da partida viu a máquina de estados andar")
	_check(match_log.total() >= 3, "o log da partida deve ter vários eventos (%d)" % match_log.total())
	var seen := {}
	for node in match_scene.find_children("*", "", true, false):
		var phase: int = order.phase_of(node)
		if phase >= 0:
			_check(node.process_priority == order.PRIORITY[phase], "%s (fase %d) está com prioridade %d" % [node.get_path(), phase, node.process_priority])
			seen[phase] = true
	for phase in [order.Phase.INPUT, order.Phase.GAMEPLAY, order.Phase.AI, order.Phase.WORLD, order.Phase.UI, order.Phase.RENDER]:
		_check(seen.has(phase), "a partida deveria ter módulos na fase %d" % phase)
	var late: Node = load("res://scripts/ui/minimap_markers.gd").new()
	match_scene.add_child(late)
	_check(late.process_priority == order.PRIORITY[order.Phase.UI], "módulo que entra depois também recebe a fase")

	if not _failed:
		print("OK")
		quit(0)
