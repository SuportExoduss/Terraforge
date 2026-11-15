extends SceneTree
## Teste de fumaça do Passo 113 (posição no ranking na HUD): a pílula só aparece com um rival conhecido, mostra 1 + quantos
## rivais têm mais domínio (empate não ultrapassa), eliminado fica atrás, líder em âmbar, e o domínio dos rivais não vira texto.
## Uso: godot_console --headless --path . -s res://tools/smoke_hud_rank.gd


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # autoloads prontos
	var bus := root.get_node("EventBus")
	var hud = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	var pill: Control = hud.find_child("RankPill", true, false)
	var label: Label = hud.find_child("RankLabel", true, false)
	if not _check(pill != null and label != null, "RankPill e RankLabel existem"): return
	if not _check(not pill.visible, "sem rivais conhecidos a pílula fica escondida"): return
	bus.territory_score_changed.emit(1, 0.05)
	if not _check(not pill.visible, "só o jogador conhecido: continua escondida"): return
	bus.territory_score_changed.emit(2, 0.10)
	bus.territory_score_changed.emit(3, 0.02)
	if not _check(pill.visible and label.text == "2º", "5%% contra 10%% e 2%% = 2º (veio '%s')" % label.text): return
	if not _check(label.get_theme_color("font_color") == Color.WHITE, "fora do topo o número é branco"): return
	bus.territory_score_changed.emit(1, 0.10)
	if not _check(label.text == "1º", "empate com o 1º não é ultrapassado (veio '%s')" % label.text): return
	if not _check(label.get_theme_color("font_color") != Color.WHITE, "líder em âmbar"): return
	bus.territory_score_changed.emit(3, 0.30)
	if not _check(label.text == "2º", "um rival passou à frente: 2º"): return
	bus.civilization_eliminated.emit(3)
	if not _check(label.text == "1º", "rival eliminado sai da frente: 1º"): return
	bus.territory_score_changed.emit(3, 0.50)   # evento atrasado de quem já morreu não ressuscita
	if not _check(label.text == "1º", "eliminado não volta ao ranking"): return
	if not _check((hud.find_child("ScoreLabel", true, false) as Label).text == "Domínio: 10,0%", "o domínio do jogador segue igual e só dele"): return
	hud.queue_free()
	print("OK smoke_hud_rank")
	quit(0)
