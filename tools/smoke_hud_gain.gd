extends SceneTree
## Teste de fumaça do Passo 118 (feedback flutuante, DD-158): depois da largada, cada ganho/perda de domínio do JOGADOR
## (≥ 0,4 ponto) vira "+x,x%" verde / "-x,x%" vermelho no meio da tela; corte de rastro e eliminação feitos pelo jogador
## viram texto âmbar; rival, variação pequena e antes da largada não mostram nada; o texto some sozinho e o maior feito sai maior.
## Uso: godot_console --headless --path . -s res://tools/smoke_hud_gain.gd


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
	var gain: Label = hud.find_child("GainLabel", true, false)
	if not _check(gain != null and gain.text == "", "GainLabel existe e começa vazio"): return

	# Antes da largada (conquista inicial da base) nada aparece
	bus.territory_score_changed.emit(1, 0.02)
	bus.territory_score_changed.emit(1, 0.10)
	if not _check(gain.text == "", "antes da largada não mostra '+x%%' (veio '%s')" % gain.text): return

	bus.match_started.emit()
	bus.territory_score_changed.emit(1, 0.20)
	if not _check(gain.text == "+10,0%", "ganho de 10 pontos (veio '%s')" % gain.text): return
	if not _check(gain.get_theme_color("font_color").g > gain.get_theme_color("font_color").r, "ganho em verde"): return
	var big := gain.get_theme_font_size("font_size")

	bus.territory_score_changed.emit(1, 0.202)   # +0,2 ponto: abaixo do mínimo
	if not _check(gain.text == "+10,0%", "variação pequena não troca o texto (veio '%s')" % gain.text): return
	bus.territory_score_changed.emit(2, 0.60)   # rival
	if not _check(gain.text == "+10,0%", "rival não mostra nada (veio '%s')" % gain.text): return

	bus.territory_score_changed.emit(1, 0.172)   # perdeu 3 pontos para um rival
	if not _check(gain.text == "-3,0%", "perda de 3 pontos (veio '%s')" % gain.text): return
	if not _check(gain.get_theme_color("font_color").r > gain.get_theme_color("font_color").g, "perda em vermelho"): return
	if not _check(gain.get_theme_font_size("font_size") < big, "feito menor sai menor"): return

	bus.trail_cut.emit(2, 1)   # o jogador cortou o rastro do rival
	if not _check(gain.text == "RASTRO CORTADO!", "corte feito pelo jogador (veio '%s')" % gain.text): return
	bus.civilization_killed.emit(2, 1)
	if not _check(gain.text == "ELIMINOU!", "eliminação feita pelo jogador (veio '%s')" % gain.text): return

	bus.trail_cut.emit(1, 2)   # cortaram o jogador: isso é do aviso vermelho de dano, não daqui
	bus.civilization_killed.emit(1, 2)
	if not _check(gain.text == "ELIMINOU!", "corte/morte sofridos não viram texto (veio '%s')" % gain.text): return

	await create_timer(1.5).timeout
	if not _check(gain.modulate.a < 0.05, "o texto some sozinho (alfa %.2f)" % gain.modulate.a): return
	hud.queue_free()
	print("OK smoke_hud_gain")
	quit(0)

