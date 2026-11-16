extends MenuScreen
## Tela de escolha de planeta (Passo 125, DD-165): um cartão por planeta do catálogo, em 2 colunas, com as cores do bioma, o tamanho,
## a duração, os jogadores e uma frase. Escolher grava em `Services.match_def` e no perfil. Só aparência e ritmo (DD-143): nada aqui
## dá poder. Sem class_name (use preload).


func _init() -> void:
	title_text = "ESCOLHA O PLANETA"


func build(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	for def in PlanetDef.catalog():
		_add_card(grid, def)


func _add_card(parent: Control, def: PlanetDef) -> void:
	var chosen: bool = Services.match_def != null and Services.match_def.id == def.id
	var colors := PlanetDef.swatch(def.biome)
	var card := PanelContainer.new()
	card.name = "P_%s" % def.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiTheme.card(colors[0].lightened(0.35), chosen))   # escolhido = borda âmbar
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var swatch := HBoxContainer.new()   # as 3 cores do bioma: terra escura, terra clara, água
	swatch.add_theme_constant_override("separation", 4)
	for color in colors:
		var chip := ColorRect.new()
		chip.color = color
		chip.custom_minimum_size = Vector2(46.0, 14.0)
		swatch.add_child(chip)
	col.add_child(swatch)
	col.add_child(make_label(def.display_name, 24, "Name"))
	var info := make_label("%d%% do tamanho · %d min · %d jogadores" % [def.size_percent(), roundi(def.duration_seconds / 60.0), def.bots + 1], 14, "Info")
	info.theme_type_variation = "DimLabel"
	col.add_child(info)
	var text := make_label(def.blurb, 14, "Blurb")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(0.0, 48.0)   # cabe 2 linhas: os botões dos cartões ficam alinhados
	col.add_child(text)
	var pick := Button.new()
	pick.name = "Pick"
	pick.text = "ESCOLHIDO" if chosen else "ESCOLHER"
	pick.disabled = chosen
	pick.custom_minimum_size = Vector2(0.0, 48.0)
	pick.pressed.connect(func():
		Services.match_def = def
		Profile.data["planet"] = def.id
		Profile.save()
		_refresh(def.id))
	col.add_child(pick)


## Remonta os cartões depois de escolher; o foco vai para o VOLTAR (a escolha já está feita).
func _refresh(_id: String) -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	build(body)
	back.grab_focus()
