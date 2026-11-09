extends SceneTree
## Teste de fumaça (item 5): a contagem da abertura (5..1) nunca repete um número.
## Uso: godot_console --headless --path . -s res://tools/smoke_countdown.gd

var _base: Node
var _seen: Array = []
var _frames := 0


func _initialize() -> void:
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	_base = main_scene.get_node("HomeBase")
	_base.opening_seconds = 4.0   # descida mais curta; a contagem continua sendo os 3 s finais + 2 s de nave pousada
	root.add_child(main_scene)
	root.get_node("EventBus").respawn_countdown.connect(func(id, s): if id == 1: _seen.append(s))


func _process(_delta: float) -> bool:
	_frames += 1
	if _base.state != 1 and _frames < 3000:   # 1 = GROUNDED (GO!)
		return false
	var ok := _frames < 3000 and _seen.size() >= 4
	for i in range(1, _seen.size()):
		ok = ok and _seen[i] < _seen[i - 1]
	print(("OK    " if ok else "FALHOU ") + "contagem sem repetir: %s" % [_seen])
	quit(0 if ok else 1)
	return true
