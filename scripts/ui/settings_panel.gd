class_name SettingsPanel
extends Control
## Tela de configurações (UI-006): dois controles de volume e três níveis de qualidade. Tudo aplica na hora (Settings);
## salva ao soltar o controle e ao voltar. `closed` avisa o dono (o menu) para tirar a tela.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preload("res://scripts/ui/ui_theme.gd").backdrop())   # Passo 112 (DD-149): mesmo fundo e cartão de vidro das outras telas

	var center := MenuScreen.scrolling_center(self)
	var card := PanelContainer.new()
	card.name = "Card"
	center.add_child(card)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(420.0, 0.0)
	box.add_theme_constant_override("separation", 8)   # cabe nos 540 px do celular deitado
	card.add_child(box)

	var title := Label.new()
	title.text = "CONFIGURAÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)

	_add_slider(box, "Sfx", "EFEITOS", "sfx")
	_add_slider(box, "Music", "MÚSICA", "music")
	_add_slider(box, "Turn", "GIRO (50% A 150%)", "turn")
	_add_slider(box, "Text", "TEXTO DA HUD (100% A 150%)", "text")

	var quality_label := Label.new()
	quality_label.text = "QUALIDADE GRÁFICA"
	box.add_child(quality_label)
	var row := HBoxContainer.new()
	row.name = "Quality"
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var group := ButtonGroup.new()
	for level in Settings.QUALITY_NAMES.size():
		var button := Button.new()
		button.name = "Q%d" % level
		button.text = Settings.QUALITY_NAMES[level]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = level == int(Settings.get_value("quality"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.pressed.connect(func(): Settings.set_value("quality", level))
		row.add_child(button)

	var reduce := CheckButton.new()
	reduce.name = "ReduceMotion"
	reduce.text = "REDUZIR MOVIMENTO (sem meteoros, auroras e relâmpagos)"
	reduce.button_pressed = Settings.reduced_motion()
	reduce.toggled.connect(func(on: bool): Settings.set_value("reduce_motion", 1.0 if on else 0.0))
	box.add_child(reduce)

	var back := Button.new()
	back.name = "Back"
	back.text = "VOLTAR"
	back.custom_minimum_size = Vector2(240.0, 46.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	box.add_child(back)
	back.grab_focus()


func close() -> void:
	Profile.save()
	closed.emit()


func _add_slider(parent: Control, node_name: String, label_text: String, key: String) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get_value(key)
	slider.custom_minimum_size = Vector2(0.0, 24.0)
	slider.value_changed.connect(func(value: float): Settings.set_value(key, value, false))
	slider.drag_ended.connect(func(_changed: bool): Profile.save())
	parent.add_child(slider)
