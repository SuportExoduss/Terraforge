extends SceneTree
## Teste de fumaça do Passo 109 (DD-149, tema visual): (1) o Theme global está na janela raiz com as variações PrimaryButton/GhostButton/
## TitleLabel/CoinLabel/GemLabel/ProfileLabel; (2) contraste de texto >= 4,5:1 (WCAG) nas combinações principais; (3) o menu é uma coluna
## à esquerda com hierarquia: JOGAR é o único botão âmbar e o maior, o dock tem os 6 atalhos em grade (Missões entrou no Passo 115), CONFIGURAÇÕES e SAIR são discretos;
## (4) as telas do menu ganham um cartão de vidro; (5) na loja o item EQUIPADO ganha borda âmbar e só o COMPRAR da linha ativa (mouse/foco) e que dá para pagar é âmbar (Passo 119).
## Uso: godot_console --headless --path . -s res://tools/smoke_theme.gd

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const TEST_PROFILE := "user://profile_smoke_theme.json"


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # o _ready dos autoloads (Services aplica o tema) roda no 1º quadro
	var profile = load("res://scripts/core/profile.gd")
	var cos = load("res://scripts/core/cosmetics.gd")
	profile.path = TEST_PROFILE
	DirAccess.remove_absolute(TEST_PROFILE)
	profile.load_data()
	profile.data["matches"] = 1   # quem já jogou (a 1ª partida é o treino)

	# 1. O tema global está na raiz
	var theme: Theme = root.theme
	if not _check(theme != null, "Services deve aplicar o tema na janela raiz"): return
	for pair in [["PrimaryButton", "Button"], ["GhostButton", "Button"], ["TitleLabel", "Label"], ["CoinLabel", "Label"], ["GemLabel", "Label"], ["ProfileLabel", "Label"]]:
		if not _check(theme.get_type_variation_base(pair[0]) == pair[1], "variação %s sobre %s" % pair): return
	var primary_style = theme.get_stylebox("normal", "PrimaryButton")
	if not _check(primary_style is StyleBoxFlat and primary_style.bg_color.is_equal_approx(UiTheme.FORGE), "PrimaryButton é âmbar cheio"): return

	# 2. Contraste (texto >= 4,5:1)
	var glass := Color(UiTheme.GLASS.r, UiTheme.GLASS.g, UiTheme.GLASS.b)
	var checks := {
		"texto sobre vidro": _contrast(UiTheme.INK, glass),
		"texto apagado sobre vidro": _contrast(UiTheme.INK_DIM, glass),
		"moedas sobre vidro": _contrast(UiTheme.COIN, glass),
		"gemas sobre vidro": _contrast(UiTheme.GEM, glass),
		"texto do botão âmbar": _contrast(theme.get_color("font_color", "PrimaryButton"), UiTheme.FORGE),
		"texto sobre o fundo do menu": _contrast(UiTheme.INK, UiTheme.SPACE),
	}
	for key in checks:
		if not _check(checks[key] >= 4.5, "contraste baixo: %s = %.2f" % [key, checks[key]]): return

	# 3. Menu: coluna com hierarquia
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var screen: Vector2 = menu.get_viewport_rect().size
	var play: Button = menu.get_node("Box/Play")
	if not _check(play.theme_type_variation == "PrimaryButton" and play.size.y >= 60.0, "JOGAR é o botão principal e grande"): return
	var style = play.get_theme_stylebox("normal")
	if not _check(style is StyleBoxFlat and style.bg_color.is_equal_approx(UiTheme.FORGE), "JOGAR sai em âmbar"): return
	var primary := 0
	for button in menu.get_node("Box").find_children("*", "Button", true, false):
		if button.theme_type_variation == "PrimaryButton":
			primary += 1
		if not _check(button == play or button.size.y < play.size.y, "nenhum botão é maior que JOGAR"): return
		var rect: Rect2 = button.get_global_rect()
		if not _check(rect.position.x >= 0.0 and rect.end.x <= screen.x and rect.position.y >= 0.0 and rect.end.y <= screen.y, "botão %s fora da tela (%s)" % [button.name, rect]): return
	if not _check(primary == 1, "só JOGAR é âmbar no menu (achei %d)" % primary): return
	var dock = menu.get_node("Box/Dock")
	if not _check(dock is GridContainer and dock.get_child_count() == 6 and dock.columns == 3, "dock: 6 atalhos em grade de 3 colunas"): return
	if not _check(menu.get_node("Box/Footer/Settings").theme_type_variation == "GhostButton" and menu.get_node("Box/Footer/Quit").theme_type_variation == "GhostButton", "CONFIGURAÇÕES e SAIR são discretos"): return
	if not _check(menu.get_node("Box/Title").theme_type_variation == "TitleLabel" and menu.get_node("Box/Profile").theme_type_variation == "ProfileLabel", "título e perfil usam as variações do tema"): return
	var shade = menu.get_node_or_null("Shade")
	if not _check(shade != null and shade.get_index() > menu.get_node("Backdrop").get_index() and shade.get_index() < menu.get_node("Box").get_index(), "sombra lateral entre o planeta e os botões"): return
	menu.queue_free()

	# 4. Telas do menu: cartão de vidro; 5. Loja: equipado âmbar, COMPRAR âmbar só se pagável
	var shop = load("res://scripts/ui/shop_screen.gd").new()
	root.add_child(shop)
	await process_frame
	await process_frame
	var card = shop.find_child("Card", true, false)
	if not _check(card is PanelContainer and card.size.x >= 600.0, "a loja fica num cartão de vidro"): return
	var cards: Dictionary = shop.get("_cards")
	var equipped_style = cards["trail_default"].get_theme_stylebox("panel")
	if not _check(equipped_style.border_color.is_equal_approx(UiTheme.FORGE), "o item equipado tem borda âmbar"): return
	var other: Array = cos.items("trail")[1]
	var other_style = cards["trail_" + other[0]].get_theme_stylebox("panel")
	if not _check(not other_style.border_color.is_equal_approx(UiTheme.FORGE), "o item não equipado não é âmbar"): return
	profile.data["coins"] = 100000
	shop.call("_refresh")
	var buy: Button = shop.find_child("Item_trail_" + other[0], true, false)
	if not _check(buy.text.begins_with("COMPRAR") and not buy.disabled and buy.theme_type_variation == "", "COMPRAR que dá para pagar fica neutro em repouso (Passo 119)"): return
	buy.mouse_entered.emit()
	if not _check(buy.theme_type_variation == "PrimaryButton", "COMPRAR da linha sob o mouse que dá para pagar é âmbar"): return
	buy.mouse_exited.emit()
	profile.data["coins"] = 0
	shop.call("_refresh")
	if not _check(buy.disabled and buy.theme_type_variation == "", "sem saldo o COMPRAR não é âmbar"): return
	if not _check(shop.find_child("Coins", true, false).theme_type_variation == "CoinLabel" and shop.find_child("Gems", true, false).theme_type_variation == "GemLabel", "moedas e gemas têm cor própria"): return
	shop.queue_free()

	print("tema: variações, contraste >= 4,5:1, menu em coluna com JOGAR âmbar, loja em cartões")
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
