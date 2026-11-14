extends SceneTree
## Teste de fumaça (SYS-004 BALANCEAMENTO + DD-128): o limite de eventos simultâneos é SEMPRE 1, mesmo com 6 corredores
## (1 jogador + 5 robôs). O Passo 79 fazia o limite crescer com os jogadores (Cap 03 P07); o DD-128 ("1 por vez") é mais
## recente e vence. Aqui: limit() == 1, nunca 2 eventos em AVISO/EXECUÇÃO e ao menos 2 eventos diferentes chegam à EXECUÇÃO.
## Uso: godot_console --headless --path . -s res://tools/smoke_event_limit.gd

const RUNNING := [2, 3]   # GlobalEvent.State: AVISO, EXECUÇÃO (sem citar a classe em scripts -s)
const ACTIVE := 3

var _match: Node
var _events: Array = []
var _gate: GDScript
var _time := 0.0
var _max_seen := 0
var _reached := {}


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
		if event.state == ACTIVE:
			_reached[event.name] = true
	_max_seen = maxi(_max_seen, running)
	if running > 1:
		print("FALHOU: %d eventos ao mesmo tempo com %d corredores (DD-128: 1 por vez)" % [running, get_nodes_in_group("runners").size()])
		quit(1)
	elif _reached.size() >= 2:
		var runners := get_nodes_in_group("runners").size()
		var ok: bool = runners == 6 and _gate.limit() == 1
		print("OK" if ok else "FALHOU: %d corredores, limite %d (esperado 6 e 1)" % [runners, _gate.limit()])
		quit(0 if ok else 1)
	elif _time > 90.0:
		print("FALHOU: só %d evento(s) chegaram à execução em 90 s" % _reached.size())
		quit(1)
	return false
