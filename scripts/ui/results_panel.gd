class_name ResultsPanel
extends CanvasLayer
## Tela de resultados (R1): acompanha o domínio de TODAS as civilizações só ouvindo o EventBus e, no fim da
## partida, mostra o ranking — sobreviventes pelo domínio final, depois os ELIMINADOS pelo AUGE que atingiram.
## O painel não engole toques: o planeta continua girável pela câmera de contemplação por trás dele.
## Dois botões fecham o fluxo do cap. 04 (Resultados → Menu): JOGAR DE NOVO recarrega a partida, MENU volta ao início.
## ponytail: texto puro, sem pódio 3D.

const FOCUS_DELAY := 0.6   # Passo 71: espera antes de dar foco ao JOGAR DE NOVO

var _panel: PanelContainer
var _text: RichTextLabel
var _stats: RichTextLabel   # "SUAS ESTATÍSTICAS" (apuração, MatchStats)
var _rewards: RichTextLabel # "RECOMPENSAS" (XP, moedas, nível, conquistas: MatchRewards)


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 24.0   # celular deitado: só 540 px de altura
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

	# Duas colunas (celular deitado, 960x540): ranking à esquerda; estatísticas e recompensas à direita.
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 32)
	box.add_child(columns)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("separation", 10)

	_text = RichTextLabel.new()
	_text.name = "Ranking"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 22)
	columns.add_child(_text)
	columns.add_child(side)

	_stats = _text.duplicate()   # mesmo estilo, fonte menor
	_stats.name = "Stats"
	_stats.add_theme_font_size_override("normal_font_size", 17)
	_stats.add_theme_font_size_override("bold_font_size", 17)
	side.add_child(_stats)

	_rewards = _stats.duplicate()
	_rewards.name = "Rewards"
	side.add_child(_rewards)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_add_button(buttons, "PlayAgain", "JOGAR DE NOVO", func(): get_tree().reload_current_scene())
	_add_button(buttons, "Menu", "MENU", _go_menu)

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


# TALLY = a apuração; RESULTS = a tela (cap. 04: o painel só aparece depois da contagem e do replay).
func _on_state(state: int) -> void:
	if state == MatchFlow.State.TALLY:
		_tally()
	elif state == MatchFlow.State.RESULTS:
		_rewards.text = _rewards_text()   # a concessão já aconteceu na apuração
		_panel.visible = true
		# Passo 71 (DD-038): ENTER já joga de novo. O foco vem com atraso: quem acabou de pular o replay com ENTER/ESPAÇO
		# não reinicia a partida sem querer antes de ver o resultado.
		get_tree().create_timer(FOCUS_DELAY).timeout.connect(func() -> void:
			if is_instance_valid(_panel) and _panel.visible:
				(_panel.get_node("Box/Buttons/PlayAgain") as Button).grab_focus())


func _tally() -> void:
	var stats := Services.stats
	var lines: PackedStringArray = ["[center][b]RESULTADO FINAL[/b][/center]", ""]
	if stats != null:
		var place := 1
		for id: int in stats.ranking():
			if stats.is_eliminated(id):
				lines.append("%dº  %s — ELIMINADO (máx %s)" % [place, _name(id), _percent(stats.peak(id))])
			else:
				lines.append("%dº  %s — %s" % [place, _name(id), _percent(stats.dominance(id))])
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


func _rewards_text() -> String:
	var rewards := Services.rewards
	if rewards == null or rewards.last.is_empty():
		return ""
	var last: Dictionary = rewards.last
	var lines: PackedStringArray = ["[center][b]RECOMPENSAS[/b][/center]",
			"+%d XP   +%d moedas" % [last["xp"], last["coins"]],
			"Nível %d" % last["level"] + ("  — SUBIU DE NÍVEL!" if last["level"] > last["level_before"] else "")]
	for id: String in last.get("new_achievements", []):
		lines.append("CONQUISTA: [b]%s[/b]" % Achievements.title_of(id))
	return "\n".join(lines)


func _name(owner_id: int) -> String:
	return "[b]VOCÊ[/b]" if owner_id == Civilization.PLAYER_ID else "Civilização %d" % owner_id


func _percent(fraction: float) -> String:
	return ("%.1f%%" % (fraction * 100.0)).replace(".", ",")
