class_name ShopScreen
extends MenuScreen
## Loja cosmética (Passo 43; categorias e raridades por dados no Passo 107, DD-147; abas, gemas e prévia no Passo 108, DD-148):
## uma ABA por categoria do catálogo (cor da cerca, moldura e título do perfil). MOEDAS pagam comum, raro e épico; GEMAS pagam
## o lendário. Cada linha vira COMPRAR (preço) → EQUIPAR → EQUIPADO; passar o foco ou o mouse numa linha mostra a PRÉVIA
## (moldura + título + cor da cerca) sem comprar. Só aparência; o equipado vale na partida (cerca) e no menu (moldura e título).

var _rows := {}      # "categoria_id" -> Button
var _cards := {}     # "categoria_id" -> PanelContainer (o cartão do item; borda âmbar quando equipado)
var _pages := {}     # categoria -> VBoxContainer (uma por aba)
var _preview := {}   # categoria -> id mostrado na prévia (o equipado, ou a linha em foco)
var _hot := ""       # Passo 119: linha sob mouse/foco; só o COMPRAR dela fica âmbar (antes todos os que cabiam no saldo)


func _init() -> void:
	title_text = "LOJA"


func build(parent: VBoxContainer) -> void:
	var wallet := HBoxContainer.new()
	wallet.name = "Wallet"
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet.add_theme_constant_override("separation", 28)
	var coins := make_label("", 24, "Coins")
	coins.theme_type_variation = "CoinLabel"
	wallet.add_child(coins)
	var gems := make_label("", 24, "Gems")
	gems.theme_type_variation = "GemLabel"
	wallet.add_child(gems)
	parent.add_child(wallet)
	var preview := make_label("", 20, "Preview")   # como o perfil e a cerca ficariam
	preview.theme_type_variation = "ProfileLabel"
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(preview)
	var trail := ColorRect.new()
	trail.name = "PreviewTrail"
	trail.custom_minimum_size = Vector2(0.0, 8.0)
	parent.add_child(trail)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(tabs)
	var group := ButtonGroup.new()
	for category: Array in Cosmetics.CATEGORIES:
		var cat: String = category[0]
		var tab := Button.new()
		tab.name = "Tab_" + cat
		tab.text = String(category[1])
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0.0, 48.0)   # Passo 129: altura de dedo
		tab.button_group = group
		tab.add_theme_font_size_override("font_size", 16)
		tab.pressed.connect(func(): _show_tab(cat))
		tabs.add_child(tab)
		var page := VBoxContainer.new()
		page.name = "Page_" + cat
		page.add_theme_constant_override("separation", 6)
		parent.add_child(page)
		_pages[cat] = page
		for item: Array in Cosmetics.items(cat):
			_add_row(page, cat, item)
	var first: String = Cosmetics.CATEGORIES[0][0]
	(tabs.get_node("Tab_" + first) as Button).button_pressed = true
	_show_tab(first)
	_refresh()


func _show_tab(cat: String) -> void:
	for page_cat: String in _pages:
		_pages[page_cat].visible = page_cat == cat
	_reset_preview()


func _add_row(parent: VBoxContainer, cat: String, item: Array) -> void:
	var rarity := Cosmetics.rarity_color(item)
	var card := PanelContainer.new()
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	_cards[cat + "_" + item[0]] = card
	var swatch := ColorRect.new()
	swatch.color = item[3] if item[3] is Color and item[3].a > 0.0 else rarity   # cor da cerca/moldura; o resto mostra a raridade
	swatch.custom_minimum_size = Vector2(36.0, 36.0)
	row.add_child(swatch)
	var name_label := make_label("%s  ·  %s" % [item[1], Cosmetics.rarity_name(item)], 22)
	name_label.add_theme_color_override("font_color", rarity)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var button := Button.new()
	button.name = "Item_%s_%s" % [cat, item[0]]
	button.custom_minimum_size = Vector2(240.0, 48.0)
	button.pressed.connect(func(): _act(cat, item[0]))
	for hover: Signal in [button.focus_entered, button.mouse_entered]:
		hover.connect(func(): _show_item(cat, item[0]))
	for leave: Signal in [button.focus_exited, button.mouse_exited]:
		leave.connect(_reset_preview)
	row.add_child(button)
	_rows[cat + "_" + item[0]] = button


func _act(cat: String, id: String) -> void:
	if not Cosmetics.is_owned(id, cat):
		Cosmetics.buy(id, cat)
	else:
		Cosmetics.equip(id, cat)
	_refresh()


func _show_item(cat: String, id: String) -> void:
	_preview[cat] = id
	_hot = cat + "_" + id
	_update_preview()
	_tint_buy()


func _reset_preview() -> void:
	for category: Array in Cosmetics.CATEGORIES:
		_preview[category[0]] = Cosmetics.equipped(category[0])
	_hot = ""
	_update_preview()
	_tint_buy()


## DD-159: a única âmbar é a ação que o jogador está prestes a fazer; os outros COMPRAR ficam neutros (a tela não grita).
func _tint_buy() -> void:
	for key: String in _rows:
		var button: Button = _rows[key]
		button.theme_type_variation = "PrimaryButton" if key == _hot and button.text.begins_with("COMPRAR") and not button.disabled else ""


func _update_preview() -> void:
	var title := String(Cosmetics.entry(_preview["title"], "title")[3])
	var label: Label = body.get_node("Preview")
	label.text = ("" if title == "" else title.to_upper() + "\n") + "Seu perfil"
	Cosmetics.dress_frame(label, Cosmetics.entry(_preview["frame"], "frame")[3])
	body.get_node("PreviewTrail").color = Cosmetics.entry(_preview["trail"], "trail")[3]


func _refresh() -> void:
	body.get_node("Wallet/Coins").text = "Moedas: %d" % int(Profile.data["coins"])
	body.get_node("Wallet/Gems").text = "Gemas: %d" % int(Profile.data.get("gems", 0))
	for category: Array in Cosmetics.CATEGORIES:
		var cat: String = category[0]
		for item: Array in Cosmetics.items(cat):
			var id: String = item[0]
			var button: Button = _rows[cat + "_" + id]
			var equipped: bool = Cosmetics.is_owned(id, cat) and Cosmetics.equipped(cat) == id
			_cards[cat + "_" + id].add_theme_stylebox_override("panel", UiTheme.card(Cosmetics.rarity_color(item), equipped))
			button.theme_type_variation = ""
			if not Cosmetics.is_owned(id, cat):
				button.text = "SÓ NO PASSE" if Cosmetics.pass_only(item) else "COMPRAR  (%s)" % Cosmetics.price_text(item)
				button.disabled = not Cosmetics.can_afford(item)
			elif equipped:
				button.text = "EQUIPADO"
				button.disabled = true
			else:
				button.text = "EQUIPAR"
				button.disabled = false
	_reset_preview()
