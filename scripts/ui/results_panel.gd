class_name ResultsPanel
extends CanvasLayer
## Tela de resultados (R1): acompanha o domínio de TODAS as civilizações só ouvindo o EventBus e, no fim da
## partida, mostra o ranking — sobreviventes pelo domínio final, depois os ELIMINADOS pelo AUGE que atingiram.
## O painel não engole toques: o planeta continua girável pela câmera de contemplação por trás dele.
## ponytail: texto puro, sem pódio 3D nem botão "jogar de novo"; entram com o menu/lobby.

var _latest := {}       # id -> domínio atual (fração)
var _peak := {}         # id -> maior domínio já visto
var _eliminated := {}   # id -> true
var _panel: PanelContainer
var _text: RichTextLabel


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

	_text = RichTextLabel.new()
	_text.name = "Ranking"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 22)
	_panel.add_child(_text)

	EventBus.territory_score_changed.connect(_on_score)
	EventBus.civilization_eliminated.connect(func(owner_id: int): _eliminated[owner_id] = true)
	EventBus.match_ended.connect(_on_match_ended)


func _on_score(owner_id: int, owned_fraction: float) -> void:
	_latest[owner_id] = owned_fraction
	_peak[owner_id] = maxf(_peak.get(owner_id, 0.0), owned_fraction)


func _on_match_ended() -> void:
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
	_panel.visible = true


func _name(owner_id: int) -> String:
	return "[b]VOCÊ[/b]" if owner_id == Civilization.PLAYER_ID else "Civilização %d" % owner_id


func _percent(fraction: float) -> String:
	return ("%.1f%%" % (fraction * 100.0)).replace(".", ",")
