extends SceneTree
## Teste de fumaça do Passo 83 (SYS-006 Defensores: "identidade visual única para cada civilização"): todo defensor
## anda com um anel no chão (CivMark) na cor viva do solo da civilização dona; defensores de civilizações diferentes
## têm anéis de cores diferentes e os da mesma civilização têm a mesma cor.
## Uso: godot_console --headless --path . -s res://tools/smoke_defender_mark.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
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


func _run() -> void:
	await _bus.match_started
	for i in 5:
		await process_frame
	var guards: Array = _match.get_node("Defenders")._guards
	var colors := {}   # dono -> cor do anel
	for guard in guards:
		var mark := guard.node.get_node_or_null("CivMark") as MeshInstance3D
		if not _check(mark != null and mark.visible, "o defensor da civilização %d leva o anel" % guard.owner_id): return
		var color: Color = (mark.mesh.material as StandardMaterial3D).albedo_color
		if not _check(not colors.has(guard.owner_id) or colors[guard.owner_id] == color, "mesma civilização, mesma cor"): return
		colors[guard.owner_id] = color
	if not _check(colors.size() == 2, "há defensores das 2 civilizações (%d)" % colors.size()): return
	if not _check(colors[1] != colors[2], "civilizações diferentes, cores diferentes"): return
	print("OK")
	quit(0)
