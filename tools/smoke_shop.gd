extends SceneTree
## Teste de fumaça do Passo 43 (loja cosmética): comprar gasta moedas do perfil e só com saldo, não compra duas vezes,
## equipar exige ter comprado, a loja mostra COMPRAR/EQUIPAR/EQUIPADO, a escolha sobrevive a recarregar o perfil e a
## cerca do jogador (só a dele) ganha a cor na partida. Só aparência.
## Uso: godot_console --headless --path . -s res://tools/smoke_shop.gd

const TEST_PROFILE := "user://profile_smoke_shop.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _tinted(trail: Node) -> Array:
	var out := []
	for mesh in trail.find_children("*", "MeshInstance3D", true, false):
		if mesh.name != "Sombra" and mesh.material_overlay != null:
			out.append(mesh)
	return out


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	var cos = load("res://scripts/core/cosmetics.gd")
	cos.offer_off = true   # Passo 134: preço cheio, sem depender da oferta da semana de hoje
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# Regras: o Original já é seu; sem moeda não compra
	if not _check(cos.is_owned("default") and cos.equipped() == "default", "Original é o padrão"): return
	if not _check(cos.equipped_tint().a == 0.0, "Original = sem tinta"): return
	if not _check(not cos.buy("ouro"), "sem moedas não compra"): return
	if not _check(not cos.is_owned("ouro"), "nada comprado"): return
	if not _check(not cos.buy("naoexiste"), "item inexistente recusado"): return
	if not _check(not cos.equip("ouro"), "não equipa o que não é seu"): return
	profile.data["coins"] = 150
	if not _check(cos.buy("ouro"), "com moedas compra"): return
	if not _check(int(profile.data["coins"]) == 90, "ouro custou 60 (sobram 90)"): return
	if not _check(not cos.buy("ouro"), "não compra duas vezes"): return
	if not _check(int(profile.data["coins"]) == 90, "recompra não gastou"): return
	if not _check(cos.equip("ouro") and cos.equipped() == "ouro", "equipa o comprado"): return
	var tint: Color = cos.equipped_tint()
	if not _check(tint.a > 0.0 and tint.r == 1.0 and absf(tint.g - 0.8) < 0.01, "tinta ouro"): return

	# Persistência
	profile.load_data()
	if not _check(cos.equipped() == "ouro" and cos.is_owned("ouro") and int(profile.data["coins"]) == 90, "compra e equipado sobrevivem ao recarregar"): return
	# equipado que deixou de ser seu volta ao Original
	profile.data["equipped_trail"] = "magenta"
	if not _check(cos.equipped() == "default", "equipado não comprado cai no Original"): return
	profile.data["equipped_trail"] = "ouro"

	# Tela da loja
	var screen = load("res://scripts/ui/shop_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var b_def = screen.find_child("Item_trail_default", true, false)
	var b_ouro = screen.find_child("Item_trail_ouro", true, false)
	var b_ciano = screen.find_child("Item_trail_ciano", true, false)
	var b_mag = screen.find_child("Item_trail_magenta", true, false)
	if not _check(b_def != null and b_ouro != null and b_ciano != null and b_mag != null, "um botão por item"): return
	if not _check(b_ouro.text == "EQUIPADO" and b_ouro.disabled, "ouro aparece EQUIPADO"): return
	if not _check(b_def.text == "EQUIPAR" and not b_def.disabled, "Original aparece EQUIPAR"): return
	if not _check(b_ciano.text.begins_with("COMPRAR") and not b_ciano.disabled, "ciano (80) cabe nas 90 moedas"): return
	if not _check(b_mag.text.begins_with("COMPRAR") and b_mag.disabled, "magenta (100) falta moeda"): return
	if not _check(screen.find_child("Coins", true, false).text.contains("90"), "saldo mostrado"): return
	# Passo 119 (DD-159): âmbar só no COMPRAR da linha sob mouse/foco, e só se der para comprar
	if not _check(b_ciano.theme_type_variation == "", "COMPRAR que cabe no saldo fica neutro em repouso"): return
	b_ciano.mouse_entered.emit()
	if not _check(b_ciano.theme_type_variation == "PrimaryButton", "linha sob o mouse com saldo: âmbar"): return
	b_mag.mouse_entered.emit()
	if not _check(b_ciano.theme_type_variation == "" and b_mag.theme_type_variation == "", "só a linha ativa; sem saldo continua neutro"): return
	b_mag.mouse_exited.emit()
	if not _check(b_ciano.theme_type_variation == "" and b_mag.theme_type_variation == "", "ao sair, ninguém é âmbar"): return
	b_ciano.pressed.emit()
	if not _check(int(profile.data["coins"]) == 10 and cos.is_owned("ciano"), "apertar COMPRAR compra"): return
	if not _check(b_ciano.text == "EQUIPAR" and screen.find_child("Coins", true, false).text.contains("10"), "vira EQUIPAR e o saldo atualiza"): return
	if not _check(b_mag.disabled and screen.find_child("Item_trail_verde", true, false).disabled, "o resto continua sem saldo"): return
	b_ciano.pressed.emit()
	if not _check(cos.equipped() == "ciano" and b_ciano.text == "EQUIPADO" and b_ouro.text == "EQUIPAR", "apertar EQUIPAR troca o equipado"): return
	b_ouro.pressed.emit()   # volta para o ouro, que é o que a partida vai mostrar
	if not _check(cos.equipped() == "ouro", "re-equipa o ouro"): return
	screen.queue_free()

	# Menu: LOJA abre a tela, comprar atualiza o saldo do perfil mostrado no menu ao VOLTAR
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var dock_button = menu.get_node_or_null("Box/Dock/Shop")
	if not _check(dock_button != null, "menu tem o botão LOJA"): return
	dock_button.pressed.emit()
	await process_frame
	var opened = menu.get_node_or_null("Screen")
	if not _check(opened != null and opened.title_text == "LOJA", "o botão abre a loja"): return
	profile.data["coins"] = 500
	opened.find_child("Item_trail_magenta", true, false).pressed.emit()   # compra (100): sobram 400
	opened.back.pressed.emit()
	await process_frame
	await process_frame
	if not _check(menu.get_node_or_null("Screen") == null, "VOLTAR fecha a loja"): return
	if not _check(menu.get_node("Box/Profile").text.contains("400 moedas"), "o menu mostra o saldo novo"): return
	menu.queue_free()
	profile.data["coins"] = 10

	# Partida: só a cerca do jogador ganha a cor (a do bot fica como está)
	var match_node: Node = load("res://scenes/match.tscn").instantiate()
	match_node.get_node("MatchSetup").skip_ceremony = true
	match_node.get_node("MatchSetup").bot_count = 1
	root.add_child(match_node)
	await root.get_node("EventBus").match_started
	await process_frame
	var mine := _tinted(match_node.get_node("Main/Runner/Trail"))
	var theirs := _tinted(match_node.get_node("Main/Runner2/Trail"))
	if not _check(not mine.is_empty(), "cerca do jogador tem tinta"): return
	var color: Color = mine[0].material_overlay.albedo_color
	if not _check(absf(color.g - 0.8) < 0.01 and color.a > 0.0, "a tinta é a do ouro"): return
	if not _check(theirs.is_empty(), "cerca do bot sem tinta"): return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_shop")
	quit(0)
