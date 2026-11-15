class_name ShopScreen
extends MenuScreen
## Loja cosmética (Passo 43; categorias e raridades por dados no Passo 107, DD-147): um bloco por categoria do catálogo
## (cor da cerca, moldura e título do perfil), pagas com as moedas do perfil. Cada linha vira COMPRAR (preço) → EQUIPAR →
## EQUIPADO. Só aparência; o equipado vale na partida (cerca) e no menu (moldura e título).

var _rows := {}   # "categoria_id" -> Button


func _init() -> void:
	title_text = "LOJA"


func build(parent: VBoxContainer) -> void:
	parent.add_child(make_label("", 22, "Coins"))
	for category: Array in Cosmetics.CATEGORIES:
		var cat: String = category[0]
		parent.add_child(make_label(String(category[1]), 16))
		for item: Array in Cosmetics.items(cat):
			_add_row(parent, cat, item)
	_refresh()


func _add_row(parent: VBoxContainer, cat: String, item: Array) -> void:
	var rarity := Cosmetics.rarity_color(item)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
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
	button.custom_minimum_size = Vector2(220.0, 40.0)
	button.pressed.connect(func(): _act(cat, item[0]))
	row.add_child(button)
	_rows[cat + "_" + item[0]] = button


func _act(cat: String, id: String) -> void:
	if not Cosmetics.is_owned(id, cat):
		Cosmetics.buy(id, cat)
	else:
		Cosmetics.equip(id, cat)
	_refresh()


func _refresh() -> void:
	body.get_node("Coins").text = "Moedas: %d" % int(Profile.data["coins"])
	for category: Array in Cosmetics.CATEGORIES:
		var cat: String = category[0]
		for item: Array in Cosmetics.items(cat):
			var id: String = item[0]
			var button: Button = _rows[cat + "_" + id]
			if not Cosmetics.is_owned(id, cat):
				button.text = "COMPRAR  (%d)" % item[2]
				button.disabled = int(Profile.data["coins"]) < int(item[2])
			elif Cosmetics.equipped(cat) == id:
				button.text = "EQUIPADO"
				button.disabled = true
			else:
				button.text = "EQUIPAR"
				button.disabled = false
