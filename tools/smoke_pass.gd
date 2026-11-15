extends SceneTree
## Teste de fumaça do Passo 123 (passe de temporada, DD-163): XP do passe abre níveis de 150 em 150; só resgata nível alcançado e
## uma vez; moedas/gemas entram no saldo; cosmético exclusivo do passe vira seu, não se compra na loja ("SÓ NO PASSE") e sobrevive
## a recarregar o perfil; passe completo trava em 20 níveis; a tela PASSE mostra as prontas + 3 próximas e resgata; o menu tem a faixa.
## Uso: godot_console --headless --path . -s res://tools/smoke_pass.gd

const TEST_PROFILE := "user://profile_smoke_pass.json"
const SeasonPass := preload("res://scripts/core/season_pass.gd")
const UPCOMING := 3   # igual ao da PassScreen


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # autoloads prontos
	var profile = load("res://scripts/core/profile.gd")
	var cos = load("res://scripts/core/cosmetics.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()
	var total: int = SeasonPass.TRACK.size()

	# Regras: começa zerado; 149 XP ainda não abre o nível 1
	if not _check(SeasonPass.xp() == 0 and SeasonPass.tiers_reached() == 0 and SeasonPass.claimable() == 0, "passe novo vazio"): return
	SeasonPass.add_xp(149)
	if not _check(SeasonPass.tiers_reached() == 0 and SeasonPass.xp_in_tier() == 149 and not SeasonPass.claim(1), "149 XP não abre o nível 1"): return
	SeasonPass.add_xp(1)
	if not _check(SeasonPass.tiers_reached() == 1 and SeasonPass.claimable() == 1 and SeasonPass.xp_in_tier() == 0, "150 XP abre o nível 1"): return
	if not _check(not SeasonPass.claim(2) and not SeasonPass.claim(0) and not SeasonPass.claim(total + 1), "nível não alcançado/inexistente não resgata"): return
	if not _check(SeasonPass.claim(1) and int(profile.data["coins"]) == 30, "nível 1 dá 30 moedas"): return
	if not _check(not SeasonPass.claim(1) and int(profile.data["coins"]) == 30 and SeasonPass.claimable() == 0, "não resgata duas vezes"): return
	SeasonPass.add_xp(-50)
	if not _check(SeasonPass.xp() == 150, "XP negativo não tira nada"): return

	# Cosmético exclusivo: nível 5 = cor da cerca Eclipse
	SeasonPass.add_xp(150 * 4)
	if not _check(SeasonPass.tiers_reached() == 5 and SeasonPass.claimable() == 4, "5 níveis alcançados, 4 por resgatar"): return
	var eclipse: Array = cos.entry("eclipse", "trail")
	if not _check(cos.pass_only(eclipse) and not cos.can_afford(eclipse) and not cos.buy("eclipse") and not cos.is_owned("eclipse"), "Eclipse não se compra"): return
	profile.data["coins"] = 9999
	profile.data["gems"] = 9999
	for cat: Array in cos.CATEGORIES:
		for item: Array in cos.items(cat[0]):
			if cos.pass_only(item) and not _check(not cos.buy(item[0], cat[0]), "exclusivo %s não compra nem rico" % item[0]): return
	profile.data["coins"] = 30
	profile.data["gems"] = 0
	for t in range(2, 6):
		if not _check(SeasonPass.claim(t), "resgata o nível %d" % t): return
	if not _check(cos.is_owned("eclipse") and cos.equip("eclipse") and cos.equipped() == "eclipse", "Eclipse é seu e equipa"): return
	if not _check(int(profile.data["coins"]) == 30 + 40 + 50 and int(profile.data["gems"]) == 2, "moedas/gemas dos níveis 2-5"): return
	profile.load_data()
	if not _check(cos.is_owned("eclipse") and SeasonPass.is_claimed(5) and SeasonPass.xp() == 150 * 5, "tudo sobrevive ao recarregar"): return

	# Textos
	if not _check(SeasonPass.reward_text(1) == "30 moedas" and SeasonPass.reward_text(3) == "2 gemas" and SeasonPass.reward_text(5) == "Eclipse (cor da cerca)", "textos das recompensas"): return
	if not _check(SeasonPass.reward_text(10) == "Forja (moldura)" and SeasonPass.reward_text(20) == "Forjador de Mundos (título)", "textos dos cosméticos"): return
	if not _check(SeasonPass.result_line(4).contains("Passe: nível 5/%d" % total) and not SeasonPass.result_line(5).contains("Recompensa nova") and SeasonPass.result_line(4).contains("Recompensa nova no PASSE"), "linha dos resultados"): return

	# Loja: o exclusivo aparece "SÓ NO PASSE" e desabilitado; o que já é seu aparece normal
	var shop = load("res://scripts/ui/shop_screen.gd").new()
	root.add_child(shop)
	await process_frame
	var b_forja = shop.find_child("Item_frame_forja", true, false)
	var b_eclipse = shop.find_child("Item_trail_eclipse", true, false)
	if not _check(b_forja != null and b_forja.text == "SÓ NO PASSE" and b_forja.disabled, "moldura Forja na loja: SÓ NO PASSE"): return
	if not _check(b_eclipse.text == "EQUIPADO", "Eclipse já resgatado aparece EQUIPADO"): return
	shop.queue_free()

	# Passe completo: trava em 20 e resgata tudo
	SeasonPass.add_xp(99999)
	if not _check(SeasonPass.tiers_reached() == total and SeasonPass.xp_in_tier() == 0, "passe trava em %d níveis" % total): return
	for t in range(6, total + 1):
		if not _check(SeasonPass.claim(t), "resgata o nível %d" % t): return
	if not _check(SeasonPass.claimable() == 0 and cos.is_owned("forja", "frame") and cos.is_owned("forjador", "title"), "tudo resgatado, cosméticos seus"): return
	if not _check(int(profile.data["coins"]) == 1030 - 30 + 30 and int(profile.data["gems"]) == 19, "trilha inteira: 1030 moedas (30 iniciais já contadas) e 19 gemas (%d / %d)" % [int(profile.data["coins"]), int(profile.data["gems"])]): return
	if not _check(SeasonPass.result_line(total) == "Passe completo ✓", "passe completo nos resultados"): return

	# Tela: recomeça um passe com 2 níveis prontos; mostra 2 prontas + 3 próximas e RESGATAR atualiza
	profile.data["pass"] = {"xp": 150 * 2, "claimed": []}
	var screen = load("res://scripts/ui/pass_screen.gd").new()
	root.add_child(screen)
	await process_frame
	if not _check(screen.find_child("Level", true, false).text == "Nível 2 de %d" % total, "tela: Nível 2 de %d" % total): return
	var cards: Array = screen.find_children("T_*", "PanelContainer", true, false)
	if not _check(cards.size() == 2 + UPCOMING, "2 prontas + %d próximas = %d cartões (veio %d)" % [UPCOMING, 2 + UPCOMING, cards.size()]): return
	var claims: Array = screen.find_children("Claim", "Button", true, false).filter(func(b): return not b.disabled)
	if not _check(claims.size() == 2 and claims[0].theme_type_variation == "PrimaryButton", "2 RESGATAR habilitados, em âmbar"): return
	claims[0].pressed.emit()
	await process_frame
	await process_frame
	if not _check(SeasonPass.is_claimed(1) and SeasonPass.claimable() == 1, "apertar RESGATAR resgata o nível 1"): return
	var left: Array = screen.find_children("Claim", "Button", true, false).filter(func(b): return not b.disabled)
	if not _check(left.size() == 1 and screen.find_children("T_*", "PanelContainer", true, false).size() == 1 + UPCOMING, "tela remontada: 1 pronta + próximas"): return
	screen.queue_free()

	# Menu: faixa PASSE com aviso; abre a tela; voltar atualiza a faixa
	profile.save()
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var strip = menu.get_node_or_null("Box/Pass")
	if not _check(strip != null and strip.text == "PASSE  ·  1 recompensa!", "menu: faixa do passe com 1 recompensa (veio %s)" % (strip.text if strip else "nada")): return
	strip.pressed.emit()
	await process_frame
	var opened = menu.get_node_or_null("Screen")
	if not _check(opened != null and opened.title_text == "PASSE DA TEMPORADA", "a faixa abre o passe"): return
	opened.find_children("Claim", "Button", true, false).filter(func(b): return not b.disabled)[0].pressed.emit()
	await process_frame
	await process_frame
	opened.back.pressed.emit()
	await process_frame
	await process_frame
	if not _check(menu.get_node_or_null("Screen") == null and menu.get_node("Box/Pass").text == "PASSE DA TEMPORADA  ·  nível 2/%d" % total, "voltar atualiza a faixa (veio %s)" % menu.get_node("Box/Pass").text): return
	menu.queue_free()

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_pass")
	quit(0)
