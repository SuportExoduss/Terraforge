extends SceneTree
## Teste de fumaça do 6f: o painel de resultados só aparece no fim; ranqueia sobreviventes pelo domínio final
## e põe os ELIMINADOS depois, pelo auge; o minimapa some. Uso: godot_console --headless --path . -s res://tools/smoke_results.gd

var _match: Node
var _time := 0.0


func _initialize() -> void:
	Profile.path = "user://profile_smoke_results.json"   # perfil próprio: o compartilhado acumula partidas e conquistas entre os testes
	Profile.data = Profile.defaults()
	Profile.save()
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
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
	var bus := root.get_node("EventBus")
	await bus.match_started
	await process_frame
	var panel: Control = _match.get_node("Results/Panel")
	var text: RichTextLabel = _match.get_node("Results/Panel/Box/Columns/Left/Ranking")
	if not _check(not panel.visible, "painel não deveria aparecer durante a partida"): return
	if not _check(_match.get_node("Hud/Minimap").visible, "minimapa deveria estar visível durante a partida"): return

	# Voce=1 (12,5%), 2 (40%), 3 (auge 30%, eliminada), 4 (auge 5%, eliminada), 5 (3%)
	for entry in [[1, 0.125], [2, 0.30], [3, 0.30], [4, 0.05], [5, 0.03], [2, 0.40], [3, 0.0], [4, 0.0]]:
		bus.territory_score_changed.emit(entry[0], entry[1])
	bus.civilization_eliminated.emit(3)
	bus.civilization_eliminated.emit(4)
	await process_frame
	if not _check(not panel.visible, "painel não deveria aparecer antes do fim"): return

	_match.get_node("MatchFlow").pace = 0.0   # pós-jogo instantâneo
	bus.match_ended.emit()
	await process_frame
	if not _check(panel.visible, "painel deveria aparecer no fim"): return
	if not _check(not _match.get_node("Hud/Minimap").visible, "minimapa deveria sumir no fim"): return
	var lines := text.get_parsed_text().split("\n")
	var want := ["RESULTADO FINAL", "", "1º  Civilização 2 — 40,0%", "2º  VOCÊ — 12,5%", "3º  Civilização 5 — 3,0%",
			"4º  Civilização 3 — ELIMINADO (máx 30,0%)", "5º  Civilização 4 — ELIMINADO (máx 5,0%)"]
	if not _check(Array(lines) == want, "ranking:\n%s" % "\n".join(lines)): return
	# Celular deitado (960x540): o painel inteiro (ranking, estatísticas, recompensas, botões) cabe na tela
	await process_frame
	var screen := Vector2(root.content_scale_size)   # (o headless tem janela de 64x64, então vale o tamanho de projeto)
	var rect := panel.get_global_rect()
	print("painel %s em tela %s" % [rect, screen])
	if not _check(screen == Vector2(960.0, 540.0), "tela de projeto deveria ser 960x540 (paisagem), é %s" % screen): return
	if not _check(rect.position.y >= 0.0 and rect.end.y <= screen.y, "painel estoura a altura da tela: %s" % rect): return
	DirAccess.remove_absolute(Profile.path)
	print("OK")
	quit(0)
