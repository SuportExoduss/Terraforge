extends SceneTree
## Teste de fumaça do Passo 78 (SYS-004 BALANCEAMENTO: "a intensidade aumenta conforme a partida avança"): o intervalo
## sorteado entre dois eventos (cooldown) encolhe de 100 % no início para 50 % no fim da partida — nos eventos da base
## (Furacão) e no Meteoro (ciclo próprio); a paz inicial de 25 s continua valendo.
## Uso: godot_console --headless --path . -s res://tools/smoke_event_pace.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	for node_name in ["Meteors", "Hurricane"]:
		_match.get_node(node_name).min_seconds_between = 100.0
		_match.get_node(node_name).max_seconds_between = 100.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


# Relógio da partida a `left` s do fim; sorteia o próximo intervalo de cada evento e devolve [furacão, meteoro].
func _cooldowns(left: int) -> Array:
	_bus.match_clock_changed.emit(left)
	var out := []
	for node_name in ["Hurricane", "Meteors"]:
		var event: Node3D = _match.get_node(node_name)
		event._begin_cooldown()
		out.append(event._cooldown_target)
	return out


func _run() -> void:
	await _bus.match_started
	await process_frame
	get_first_node_in_group("match_timer").set_process(false)   # só este teste mexe no relógio
	var start := _cooldowns(600)
	if not _check(is_equal_approx(start[0], 100.0) and is_equal_approx(start[1], 100.0), "no começo o intervalo é inteiro: %s" % [start]): return
	var middle := _cooldowns(300)
	if not _check(is_equal_approx(middle[0], 75.0) and is_equal_approx(middle[1], 75.0), "na metade: 75 %%: %s" % [middle]): return
	var late := _cooldowns(60)
	if not _check(is_equal_approx(late[0], 55.0) and is_equal_approx(late[1], 55.0), "perto do fim: 55 %%: %s" % [late]): return
	var last := _cooldowns(0)
	if not _check(is_equal_approx(last[0], 50.0) and is_equal_approx(last[1], 50.0), "no fim: metade: %s" % [last]): return
	print("OK")
	quit(0)

