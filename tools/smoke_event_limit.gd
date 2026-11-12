extends SceneTree
## Teste de fumaça do Passo 79 (SYS-004 BALANCEAMENTO: "o número de eventos simultâneos depende da quantidade de jogadores"):
## o limite do portão é 1 para até 3 corredores e cresce 1 a cada 3 (DD-128 segue valendo: 1 jogador = nunca 2 juntos,
## coberto por smoke_event_gate). Aqui, com 6 corredores (1 jogador + 5 robôs) os eventos chegam a 2 ao mesmo tempo
## (AVISO/EXECUÇÃO) e nunca a 3.
## Uso: godot_console --headless --path . -s res://tools/smoke_event_limit.gd

const RUNNING := [2, 3]   # GlobalEvent.State: AVISO, EXECUÇÃO (sem citar a classe em scripts -s)

var _match: Node
var _events: Array = []
var _gate: GDScript
var _time := 0.0
var _max_seen := 0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 5
	for node_name in ["Meteors", "Earthquake", "GiantWorm", "Stampede"]:
		_match.get_node(node_name).min_seconds_between = 100000.0
		_match.get_node(node_name).max_seconds_between = 100000.0
	for node_name in ["Hurricane", "Tsunami", "Volcano", "AcidRain"]:
		var event: Node3D = _match.get_node(node_name)
		event.min_seconds_between = 2.0
		event.max_seconds_between = 2.0
		event.quiet_after_start_seconds = 0.5
		event.warning_seconds = 3.0
		event.scar_seconds = 1.0
		_events.append(event)
	_gate = load("res://scripts/world/global_event.gd")
	_gate.gate_gap_seconds = 0.2
	root.add_child(_match)


func _process(delta: float) -> bool:
	_time += delta
	var running := 0
	for event in _events:
		running += 1 if RUNNING.has(event.state) else 0
	_max_seen = maxi(_max_seen, running)
	if running > 2:
		print("FALHOU: 3 eventos ao mesmo tempo com 6 corredores")
		quit(1)
	elif _max_seen == 2:
		var runners := get_nodes_in_group("runners").size()
		print("OK" if runners == 6 and _gate.limit() == 2 else "FALHOU: %d corredores, limite %d" % [runners, _gate.limit()])
		quit(0 if runners == 6 and _gate.limit() == 2 else 1)
	elif _time > 60.0:
		print("FALHOU: nunca houve 2 eventos juntos (máximo %d)" % _max_seen)
		quit(1)
	return false
