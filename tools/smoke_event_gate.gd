extends SceneTree
## Teste de fumaça (item 7, DD-128): os 8 eventos globais com cooldown de 8 s NUNCA ficam 2 em AVISO/EXECUÇÃO ao mesmo
## tempo e respeitam a folga depois de cada execução. Também exige que ao menos 4 eventos diferentes tenham rodado.
## Uso: godot_console --headless --path . --fixed-fps 60 -s res://tools/smoke_event_gate.gd

const GAP := 3.0
const RUN_SECONDS := 240.0

var _match: Node
var _events: Array = []        # [nó, tem_execução]  (Meteors usa o enum próprio: WARNING = 2)
var _time := 0.0
var _max_running := 0
var _running_before := 0
var _gap_started := -99.0
var _gap_violation := ""
var _names := {}


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	for node_name in ["Meteors", "Tsunami", "Volcano", "Hurricane", "AcidRain", "Earthquake", "GiantWorm", "Stampede"]:
		var event: Node3D = _match.get_node(node_name)
		event.min_seconds_between = 8.0
		event.max_seconds_between = 8.0
		event.quiet_after_start_seconds = 0.5
		event.warning_seconds = 1.0
		event.scar_seconds = 1.0
		_events.append(event)
	load("res://scripts/world/global_event.gd").gate_gap_seconds = GAP
	root.add_child(_match)
	root.get_node("EventBus").global_event_warning.connect(func(n, _s): _names[n] = true)


func _running_now() -> int:
	var n := 0
	for event in _events:
		var s = event.get("state") if event.get("state") != null else event.get("_state")
		if s == 2 or (event.name != "Meteors" and s == 3):   # AVISO / EXECUÇÃO (meteoro: só o AVISO)
			n += 1
	return n


func _process(delta: float) -> bool:
	_time += delta
	if _time < 1.0:
		return false
	var running := _running_now()
	_max_running = maxi(_max_running, running)
	if running > 0 and _running_before == 0 and _time - _gap_started < GAP - 0.1 and _gap_violation == "":
		_gap_violation = "novo evento %.2f s depois do fim do anterior (folga %.1f s)" % [_time - _gap_started, GAP]
	if running == 0 and _running_before > 0:
		_gap_started = _time
	_running_before = running
	if _time < RUN_SECONDS:
		return false
	var ok := _max_running == 1 and _gap_violation == "" and _names.size() >= 4
	print(("OK    " if ok else "FALHOU ") + "máx. simultâneos=%d, eventos diferentes=%d %s%s" % [_max_running, _names.size(), _names.keys(), " — " + _gap_violation if _gap_violation != "" else ""])
	quit(0 if ok else 1)
	return true
