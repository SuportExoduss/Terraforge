class_name ResultsPanel
extends CanvasLayer
## Tela de resultados (R1): acompanha o domínio de TODAS as civilizações só ouvindo o EventBus e, no fim da
## partida, mostra o ranking — sobreviventes pelo domínio final, depois os ELIMINADOS pelo AUGE que atingiram.
## O painel não engole toques: o planeta continua girável pela câmera de contemplação por trás dele.
## Dois botões fecham o fluxo do cap. 04 (Resultados → Menu): JOGAR DE NOVO recarrega a partida, MENU volta ao início.
## ponytail: texto puro, sem pódio 3D.

var _latest := {}       # id -> domínio atual (fração)
var _peak := {}         # id -> maior domínio já visto
var _eliminated := {}   # id -> true
var _panel: PanelContainer
var _text: RichTextLabel
var _stats: RichTextLabel   # "SUAS ESTATÍSTICAS" (apuração, MatchStats)


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 90.0
	_panel.custom_minimum_size.x = 320.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.13, 0.85)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	_text = RichTextLabel.new()
	_text.name = "Ranking"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 22)
	box.add_child(_text)

	_stats = _text.duplicate()   # mesmo estilo, fonte menor
	_stats.name = "Stats"
	_stats.add_theme_font_size_override("normal_font_size", 17)
	_stats.add_theme_font_size_override("bold_font_size", 17)
	box.add_child(_stats)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_add_button(buttons, "PlayAgain", "JOGAR DE NOVO", func(): get_tree().reload_current_scene())
	_add_button(buttons, "Menu", "MENU", _go_menu)

	EventBus.territory_score_changed.connect(_on_score)
	EventBus.civilization_eliminated.connect(func(owner_id: int): _eliminated[owner_id] = true)
	EventBus.match_state_changed.connect(_on_state)


func _go_menu() -> void:
	if Services.flow != null:
		Services.flow.go(MatchFlow.State.MENU)   # STATE-013
	get_tree().change_scene_to_file(MainMenu.MENU_SCENE)


func _add_button(parent: Control, button_name: String, label: String, action: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.custom_minimum_size = Vector2(170.0, 48.0)   # alvo de toque confortável
	button.pressed.connect(action)
	parent.add_child(button)


func _on_score(owner_id: int, owned_fraction: float) -> void:
	_latest[owner_id] = owned_fraction
	_peak[owner_id] = maxf(_peak.get(owner_id, 0.0), owned_fraction)


# TALLY = a apuração; RESULTS = a tela (cap. 04: o painel só aparece depois da contagem e do replay).
func _on_state(state: int) -> void:
	if state == MatchFlow.State.TALLY:
		_tally()
	elif state == MatchFlow.State.RESULTS:
		_panel.visible = true


func _tally() -> void:
	var alive: Array = _latest.keys().filter(func(id: int) -> bool: return not _eliminated.has(id))
	alive.sort_custom(func(a: int, b: int) -> bool: return _latest[a] > _latest[b])
	var fallen: Array = _eliminated.keys()
	fallen.sort_custom(func(a: int, b: int) -> bool: return _peak.get(a, 0.0) > _peak.get(b, 0.0))

	var lines: PackedStringArray = ["[center][b]RESULTADO FINAL[/b][/center]", ""]
	var place := 1
	for id: int in alive:
		lines.append("%dº  %s — %s" % [place, _name(id), _percent(_latest[id])])
		place += 1
	for id: int in fallen:
		lines.append("%dº  %s — ELIMINADO (máx %s)" % [place, _name(id), _percent(_peak.get(id, 0.0))])
		place += 1
	_text.text = "\n".join(lines)
	_stats.text = _stats_text()


func _stats_text() -> String:
	var stats := Services.stats
	if stats == null:
		return ""
	var me := Civilization.PLAYER_ID
	return "\n".join([
		"[center][b]SUAS ESTATÍSTICAS[/b][/center]",
		"Áreas conquistadas: %d" % stats.get_stat(me, "loops"),
		"Território tomado de rivais: %s" % _percent(stats.get_stat(me, "converted")),
		"Rastros cortados: %d" % stats.get_stat(me, "cuts"),
		"Eliminações: %d" % stats.get_stat(me, "kills"),
	])


func _name(owner_id: int) -> String:
	return "[b]VOCÊ[/b]" if owner_id == Civilization.PLAYER_ID else "Civilização %d" % owner_id


func _percent(fraction: float) -> String:
	return ("%.1f%%" % (fraction * 100.0)).replace(".", ",")
