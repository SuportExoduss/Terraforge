extends SceneTree
## Teste de fumaça do Passo 95: os sentinelas nascem UM por quadro (cada um custa ~3 ms; os 6 juntos no início da partida
## davam um quadro de 17 ms), e mesmo assim todas as civilizações ficam guardadas em poucos quadros.
## Uso: godot_console --headless --path . -s res://tools/smoke_defender_stagger.gd

var _match: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 3   # 4 civilizações = 4 sentinelas a criar
	root.add_child(_match)
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _run() -> void:
	await root.get_node("EventBus").match_started
	var defenders := _match.get_node("Defenders")
	var last: int = defenders._guards.size()
	var biggest := 0
	for i in 12:
		await process_frame
		var now: int = defenders._guards.size()
		biggest = maxi(biggest, now - last)
		last = now
	var civs := {}
	for guard in defenders._guards:
		civs[guard.owner_id] = true
	if biggest > 1:
		print("FALHOU: %d sentinelas num só quadro" % biggest)
		quit(1)
		return
	if civs.size() < 4:
		print("FALHOU: só %d civilizações guardadas em 12 quadros" % civs.size())
		quit(1)
		return
	print("OK (no máximo %d por quadro, %d civilizações guardadas)" % [biggest, civs.size()])
	quit(0)
