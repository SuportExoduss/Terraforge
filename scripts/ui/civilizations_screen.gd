class_name CivilizationsScreen
extends MenuScreen
## Galeria das civilizações (Passo 41): uma linha por civilização com a cor do solo, o nome e o estado — a escolhida
## fica marcada; a que não for jogável aparece "em breve" e não responde (hoje as 6 jogam: arte ou kit procedural,
## DD-150). A escolha vale na partida (ver PlanetThemeRegistry) e fica no perfil.

var _buttons := {}   # id -> Button


func _init() -> void:
	title_text = "CIVILIZAÇÕES"


func build(parent: VBoxContainer) -> void:
	var chosen := CivilizationCatalog.chosen()
	var group := ButtonGroup.new()
	for id in range(1, CivilizationCatalog.count() + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)
		var swatch := ColorRect.new()
		swatch.name = "Swatch%d" % id
		swatch.color = CivilizationCatalog.soil_color(id)
		swatch.custom_minimum_size = Vector2(36.0, 36.0)
		row.add_child(swatch)
		var playable := CivilizationCatalog.is_playable(id)
		var button := Button.new()
		button.name = "Civ%d" % id
		button.text = CivilizationCatalog.NAMES[id - 1] + ("" if playable else "  ·  em breve")
		button.toggle_mode = true
		button.button_group = group
		button.disabled = not playable
		button.button_pressed = id == chosen
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(func(): CivilizationCatalog.choose(id))
		row.add_child(button)
		_buttons[id] = button
