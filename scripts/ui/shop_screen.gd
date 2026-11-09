class_name ShopScreen
extends MenuScreen
## Loja cosmética (Passo 43): cores de cerca à venda por moedas do perfil. Cada linha vira COMPRAR (preço) → EQUIPAR →
## EQUIPADO. Só aparência; o equipado vale na partida (RunnerTrail).

var _rows := {}   # id -> Button


func _init() -> void:
	title_text = "LOJA"


func build(parent: VBoxContainer) -> void:
	parent.add_child(make_label("", 22, "Coins"))
	parent.add_child(make_label("COR DA CERCA", 16))
	for item: Array in Cosmetics.TRAILS:
		var id: String = item[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = item[3]
		swatch.custom_minimum_size = Vector2(36.0, 36.0)
		row.add_child(swatch)
		row.add_child(make_label(String(item[1]), 22))
		row.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.name = "Item_" + id
		button.custom_minimum_size = Vector2(220.0, 40.0)
		button.pressed.connect(func(): _act(id))
		row.add_child(button)
		_rows[id] = button
	_refresh()


func _act(id: String) -> void:
	if not Cosmetics.is_owned(id):
		Cosmetics.buy(id)
	else:
		Cosmetics.equip(id)
	_refresh()


func _refresh() -> void:
	body.get_node("Coins").text = "Moedas: %d" % int(Profile.data["coins"])
	for item: Array in Cosmetics.TRAILS:
		var id: String = item[0]
		var button: Button = _rows[id]
		if not Cosmetics.is_owned(id):
			button.text = "COMPRAR  (%d)" % item[2]
			button.disabled = int(Profile.data["coins"]) < int(item[2])
		elif Cosmetics.equipped() == id:
			button.text = "EQUIPADO"
			button.disabled = true
		else:
			button.text = "EQUIPAR"
			button.disabled = false
