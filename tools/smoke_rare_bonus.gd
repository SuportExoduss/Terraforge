extends SceneTree
## Teste de fumaça do Passo 57 (Cap.03 P03 REGRAS): nenhum bônus raro (Vida Extra, Escudo Temporal) antes de 45 s.
## (1) logo após o GO!, uma queda de 30 cristais não traz nenhum raro; (2) o sorteio só libera os raros a partir de 45 s.
## Uso: godot_console --headless --path . -s res://tools/smoke_rare_bonus.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 1
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
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
	await process_frame
	await process_frame
	var bonuses: Node = _match.get_node("Bonuses")
	var planet: Node = root.get_node("Services").planet

	# 1. Integrado: logo após o GO! caem 30 cristais e nenhum é raro
	var elapsed: float = bonuses.elapsed_seconds()
	if not _check(elapsed < 5.0, "o relógio deveria estar no começo (%.1f)" % elapsed): return
	var center: Vector3 = planet.center + Vector3.UP * planet.get_surface_radius(Vector3.UP)
	_bus.bonus_drop_requested.emit(center, 30)
	var crystals := get_nodes_in_group("bonus_pickups")
	if not _check(crystals.size() == 30, "30 cristais deveriam nascer (%d)" % crystals.size()): return
	for crystal in crystals:
		var kind_name: String = crystal.name
		if not _check(not (kind_name.contains("VIDA EXTRA") or kind_name.contains("ESCUDO")), "raro antes de 45 s: " + kind_name): return

	# 2. O sorteio: 44,9 s nunca traz raro; 45 s traz os dois
	var seen := {}
	for i in 400:
		var early: int = bonuses.pick_kind(44.9)
		if not _check(not early in bonuses.RARE, "raro sorteado aos 44,9 s (%d)" % early): return
		seen[bonuses.pick_kind(45.0)] = true
	for rare in bonuses.RARE:
		if not _check(seen.has(rare), "o raro %d deveria aparecer a partir de 45 s" % rare): return
	if not _check(seen.size() == 5, "aos 45 s todos os 5 tipos entram (%d)" % seen.size()): return

	print("OK: nenhum bônus raro antes de 45 s; todos liberados a partir de 45 s")
	quit(0)
