extends SceneTree
## Teste de fumaça do Passo 84 (SYS-004 ACEITAÇÃO "eventos facilmente compreendidos"): o menu tem o atalho EVENTOS; a tela
## lista os 8 eventos globais (nome + aviso/efeito/depois), cada um com texto de verdade; VOLTAR fecha e devolve o foco.
## Uso: godot_console --headless --path . -s res://tools/smoke_events_screen.gd

const TEST_PROFILE := "user://profile_smoke_events_screen.json"

var _time := 0.0


func _initialize() -> void:
	load("res://scripts/core/profile.gd").path = TEST_PROFILE   # VOLTAR salva o perfil: não suja o de verdade
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		_fail("tempo esgotado")
	return false


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DirAccess.remove_absolute(TEST_PROFILE)
	quit(1)


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_fail(msg)
	return ok


func _run() -> void:
	await process_frame
	var menu := current_scene
	var button := menu.get_node_or_null("Box/Dock/Events") as Button
	if not _check(button != null and button.text == "EVENTOS", "o menu tem o atalho EVENTOS"): return
	button.pressed.emit()
	await process_frame
	var screen := menu.get_node_or_null("Screen")
	if not _check(screen != null and screen.find_child("Title", true, false).text == "EVENTOS", "a tela EVENTOS abre"): return

	var names := {}
	for i in 8:
		var entry := screen.find_child("Event%d" % i, true, false)
		if not _check(entry != null, "entrada Event%d existe" % i): return
		var name_text: String = entry.get_node("Name").text
		var text: String = entry.get_node("Text").text
		names[name_text] = true
		if not _check(name_text != "" and text.contains("AVISO: ") and text.contains("EFEITO: ") and text.contains("DEPOIS: "), "%s: aviso, efeito e depois" % name_text): return
		if not _check(not text.contains(": ·") and not text.ends_with(": "), "%s: nenhuma parte vazia" % name_text): return
	if not _check(names.size() == 8, "8 eventos com nomes diferentes (%d)" % names.size()): return
	if not _check(screen.find_child("Event8", true, false) == null, "só 8 entradas"): return

	screen.find_child("Back", true, false).pressed.emit()
	await process_frame
	await process_frame
	if not _check(menu.get_node_or_null("Screen") == null, "VOLTAR fecha a tela"): return
	if not _check(menu.get_node("Box/Dock/Events").has_focus(), "o foco volta ao atalho EVENTOS"): return
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
