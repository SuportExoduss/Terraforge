extends SceneTree
## Teste de fumaça do Passo 107 (DD-147, catálogo de cosméticos por dados): (1) o catálogo é íntegro — toda categoria começa com o
## item grátis "default", ids únicos, raridade conhecida, preço >= 0, e o preço não cai quando a raridade sobe; (2) comprar e equipar
## são POR CATEGORIA (a moldura "ouro" e a cerca "ouro" não se confundem) e sobrevivem a recarregar o perfil; (3) a loja tem uma
## linha por item de cada categoria; (4) o menu mostra o título equipado e a moldura equipada na linha do perfil.
## Passo 108 (DD-148): o LENDÁRIO custa GEMAS (moedas não compram), a loja tem uma aba por categoria e a prévia mostra o item em foco.
## Uso: godot_console --headless --path . -s res://tools/smoke_cosmetics.gd

const TEST_PROFILE := "user://profile_smoke_cosmetics.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	var cos = load("res://scripts/core/cosmetics.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()

	# Integridade do catálogo
	var rank := {"comum": 0, "raro": 1, "epico": 2, "lendario": 3}
	var total := 0
	for category in cos.CATEGORIES:
		var cat: String = category[0]
		var items: Array = cos.items(cat)
		if not _check(items.size() >= 4, "%s: poucos itens" % cat): return
		if not _check(items[0][0] == "default" and int(items[0][2]) == 0, "%s: o primeiro deve ser o grátis 'default'" % cat): return
		var seen := {}
		var last_price := {}   # raridade -> maior preço visto
		for item in items:
			total += 1
			if not _check(not seen.has(item[0]), "%s: id repetido %s" % [cat, item[0]]): return
			seen[item[0]] = true
			if not _check(rank.has(item[4]) and int(item[2]) >= 0, "%s/%s: raridade ou preço inválido" % [cat, item[0]]): return
			if not _check(cos.rarity_name(item) != "", "%s/%s: sem nome de raridade" % [cat, item[0]]): return
		for a in items:   # raridade maior nunca é mais barata que uma menor (na mesma moeda)
			for b in items:
				if cos.currency(a) == cos.currency(b) and rank[a[4]] > rank[b[4]] and not _check(int(a[2]) >= int(b[2]), "%s: %s (%s) mais barato que %s (%s)" % [cat, a[0], a[4], b[0], b[4]]): return
		if not _check(cos.equipped(cat) == "default", "%s: começa no padrão" % cat): return
		for item in items:   # só o lendário custa gemas; o resto, moedas
			if not _check(cos.currency(item) == ("gems" if item[4] == "lendario" else "coins"), "%s/%s: moeda pela raridade" % [cat, item[0]]): return
	if not _check(cos.frame_color().a == 0.0 and cos.title_text() == "" and cos.equipped_tint().a == 0.0, "perfil novo: sem moldura, sem título, sem tinta"): return

	# Compra e equipa por categoria (a moldura "ouro" não é a cerca "ouro")
	profile.data["coins"] = 1000
	profile.data["gems"] = 0
	if not _check(not cos.buy("aurora", "frame") and not cos.buy("lenda", "title") and int(profile.data["coins"]) == 1000, "lendário não se compra com moedas (e nada é cobrado)"): return
	if not _check(cos.buy("ouro", "frame") and not cos.is_owned("ouro", "trail") and cos.is_owned("ouro", "frame"), "comprar a moldura ouro não dá a cerca ouro"): return
	if not _check(int(profile.data["coins"]) == 1000 - int(cos.entry("ouro", "frame")[2]), "a moldura ouro cobrou o preço dela"): return
	if not _check(not cos.buy("ouro", "frame") and not cos.buy("naoexiste", "title") and not cos.buy("ouro", "naoexiste"), "recompra, item e categoria inexistentes recusados"): return
	if not _check(not cos.equip("ouro", "trail") and cos.equip("ouro", "frame") and cos.equipped("frame") == "ouro" and cos.equipped("trail") == "default", "equipar vale só na categoria"): return
	profile.data["gems"] = 120
	if not _check(cos.buy("lenda", "title") and cos.equip("lenda", "title"), "compra e equipa o título (com gemas)"): return
	if not _check(int(profile.data["gems"]) == 120 - int(cos.entry("lenda", "title")[2]) and int(profile.data["coins"]) == 1000 - int(cos.entry("ouro", "frame")[2]), "o lendário cobrou só gemas"): return
	if not _check(cos.title_text() == "Lenda do Planeta" and absf(cos.frame_color().g - 0.8) < 0.01, "título e moldura equipados lidos"): return
	var money: int = int(profile.data["coins"])
	var jewels: int = int(profile.data["gems"])
	profile.data["coins"] = 5
	profile.data["gems"] = 5
	if not _check(not cos.buy("aurora", "frame") and not cos.buy("rubi", "trail") and not cos.buy("nova", "trail"), "sem saldo não compra (moedas e gemas)"): return
	profile.data["coins"] = money
	profile.data["gems"] = jewels

	# Persistência (as chaves da cerca continuam as de sempre)
	profile.load_data()
	if not _check(cos.equipped("frame") == "ouro" and cos.equipped("title") == "lenda" and cos.is_owned("ouro", "frame"), "moldura e título sobrevivem a recarregar"): return
	if not _check(profile.data.has("owned_frames") and profile.data.has("owned_titles") and profile.data.has("equipped_frame") and profile.data.has("equipped_title"), "chaves owned_<cat>s / equipped_<cat>"): return
	profile.data["equipped_title"] = "conquistador"   # equipado que não é seu volta ao padrão
	if not _check(cos.equipped("title") == "default" and cos.title_text() == "", "título não comprado cai no padrão"): return
	profile.data["equipped_title"] = "lenda"

	# A loja tem uma linha por item
	var shop = load("res://scripts/ui/shop_screen.gd").new()
	root.add_child(shop)
	await process_frame
	var rows := 0
	for category in cos.CATEGORIES:
		for item in cos.items(category[0]):
			var button = shop.find_child("Item_%s_%s" % [category[0], item[0]], true, false)
			if not _check(button != null, "falta a linha %s/%s" % [category[0], item[0]]): return
			rows += 1
	if not _check(rows == total, "uma linha por item do catálogo (%d)" % total): return
	var b_frame = shop.find_child("Item_frame_ouro", true, false)
	var b_trail = shop.find_child("Item_trail_ouro", true, false)
	if not _check(b_frame.text == "EQUIPADO" and b_trail.text.begins_with("COMPRAR"), "a loja distingue a moldura ouro (equipada) da cerca ouro (à venda)"): return
	shop.find_child("Item_title_pioneiro", true, false).pressed.emit()   # compra
	if not _check(cos.is_owned("pioneiro", "title") and shop.find_child("Item_title_pioneiro", true, false).text == "EQUIPAR", "apertar COMPRAR no título compra"): return
	shop.find_child("Item_title_pioneiro", true, false).pressed.emit()   # equipa
	if not _check(cos.title_text() == "Pioneiro" and shop.find_child("Item_title_lenda", true, false).text == "EQUIPAR", "apertar EQUIPAR troca só o título"): return
	# Abas: uma página por categoria, só a da aba aberta aparece
	var page_trail = shop.find_child("Page_trail", true, false)
	var page_frame = shop.find_child("Page_frame", true, false)
	if not _check(page_trail.visible and not page_frame.visible, "a loja abre na 1ª aba (cor da cerca)"): return
	shop.find_child("Tab_frame", true, false).pressed.emit()
	if not _check(page_frame.visible and not page_trail.visible and not shop.find_child("Page_title", true, false).visible, "tocar na aba da moldura troca a página"): return
	# Lendário: o botão pede gemas; sem gemas fica desligado, com gemas liga
	var b_aurora = shop.find_child("Item_frame_aurora", true, false)
	if not _check(b_aurora.text.contains("(40 gemas)") and not b_aurora.disabled, "lendário mostra o preço em gemas e liga com saldo (70 gemas)"): return
	profile.data["gems"] = 0
	shop.call("_refresh")
	if not _check(b_aurora.text.contains("gemas") and b_aurora.disabled and shop.find_child("Gems", true, false).text.contains("0"), "sem gemas o lendário fica desligado e o saldo de gemas aparece"): return
	profile.data["gems"] = jewels
	shop.call("_refresh")
	# Prévia: o foco numa linha mostra o item sem comprar; sair volta ao equipado
	var preview: Label = shop.find_child("Preview", true, false)
	shop.find_child("Item_frame_prata", true, false).focus_entered.emit()
	var shown = preview.get_theme_stylebox("normal")
	if not _check(shown is StyleBoxFlat and shown.border_color.is_equal_approx(cos.entry("prata", "frame")[3]) and not cos.is_owned("prata", "frame"), "a prévia mostra a moldura prata sem comprar"): return
	shop.find_child("Item_title_cercador", true, false).focus_entered.emit()
	if not _check(preview.text.begins_with("MESTRE DAS CERCAS"), "a prévia mostra o título em foco"): return
	shop.find_child("Item_trail_gelo", true, false).focus_entered.emit()
	if not _check(shop.find_child("PreviewTrail", true, false).color.is_equal_approx(cos.entry("gelo")[3]), "a prévia mostra a cor da cerca em foco"): return
	shop.find_child("Item_trail_gelo", true, false).focus_exited.emit()
	if not _check(preview.text.begins_with("PIONEIRO") and shop.find_child("PreviewTrail", true, false).color.is_equal_approx(Color.WHITE), "sair da linha volta a prévia ao equipado"): return
	shop.queue_free()

	# O menu mostra título e moldura
	profile.data["matches"] = 1   # quem já jogou (a 1ª partida é o treino)
	profile.save()
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var line: Label = menu.get_node("Box/Profile")
	if not _check(line.text.begins_with("PIONEIRO\n") and line.text.contains("Nível ") and line.text.contains(" gemas"), "o título equipado vai acima da linha do perfil: %s" % line.text.replace("\n", "|")): return
	var style = line.get_theme_stylebox("normal")
	if not _check(style is StyleBoxFlat and style.border_color.is_equal_approx(cos.entry("ouro", "frame")[3]) and style.border_width_left == 3, "a moldura equipada é a borda da linha do perfil"): return
	profile.data["equipped_frame"] = "default"
	profile.data["equipped_title"] = "default"
	menu.call("_dress_profile", line)   # o menu refaz a linha ao voltar da loja: sem moldura nem título = linha simples
	line.text = menu.call("_profile_text")
	if not _check(line.text.begins_with("Nível ") and line.get_theme_stylebox("normal").border_width_left != 3, "sem moldura nem título: linha simples (o estilo do tema, sem a borda da moldura)"): return
	menu.queue_free()

	print("catálogo: %d itens em %d categorias; compra/equipar por categoria; menu com título e moldura" % [total, cos.CATEGORIES.size()])
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
