class_name ResultsPanel
extends CanvasLayer
## Tela de resultados (R1): acompanha o domínio de TODAS as civilizações só ouvindo o EventBus e, no fim da
## partida, mostra o ranking — sobreviventes pelo domínio final, depois os ELIMINADOS pelo AUGE que atingiram.
## O painel não engole toques: o planeta continua girável pela câmera de contemplação por trás dele.
## Dois botões fecham o fluxo do cap. 04 (Resultados → Menu): JOGAR DE NOVO recarrega a partida, MENU volta ao início.
## ponytail: texto puro, sem pódio 3D.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const SafeArea := preload("res://scripts/core/safe_area.gd")
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const Leagues := preload("res://scripts/core/leagues.gd")
const SeasonPass := preload("res://scripts/core/season_pass.gd")
const FOCUS_DELAY := 0.6   # Passo 71: espera antes de dar foco ao JOGAR DE NOVO
const MAX_ACHIEVEMENT_LINES := 4   # Passo 132: o painel cabe nos 540 px mesmo com muitas conquistas de uma vez
const BACK_DELAY_MSEC := 1000   # Passo 128: logo que os resultados abrem, VOLTAR ainda não sai deles

var _panel: PanelContainer
var _text: RichTextLabel
var _stats: RichTextLabel   # "SUAS ESTATÍSTICAS" (apuração, MatchStats)
var _rewards: RichTextLabel # "RECOMPENSAS" (XP, moedas, nível, conquistas: MatchRewards)
var _shown_msec := 0


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 24.0 + SafeArea.insets(self).y   # celular deitado: só 540 px de altura (e o entalhe, se houver)
	_panel.custom_minimum_size.x = 320.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.GLASS, 0.9)   # Passo 112 (DD-149): mesma cara de vidro do menu e da HUD
	style.set_border_width_all(1)
	style.border_color = Color(UiTheme.LINE, 0.8)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16.0)
	style.anti_aliasing = true
	_panel.add_theme_stylebox_override("panel", style)
	_panel.theme = UiTheme.build()   # filho de CanvasLayer não herda o tema da janela: aplica o mesmo tema do jogo aqui
	add_child(_panel)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	# Duas colunas (celular deitado, 960x540): ranking e estatísticas à esquerda; recompensas à direita (Passo 132: antes as
	# estatísticas ficavam sobre as recompensas e o painel estourava os 540 px quando vinham muitas conquistas de uma vez).
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 32)
	box.add_child(columns)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("separation", 10)
	var left := VBoxContainer.new()
	left.name = "Left"
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 10)

	_text = RichTextLabel.new()
	_text.name = "Ranking"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 22)
	left.add_child(_text)
	columns.add_child(left)
	columns.add_child(side)

	_stats = _text.duplicate()   # mesmo estilo, fonte menor
	_stats.name = "Stats"
	_stats.add_theme_font_size_override("normal_font_size", 17)
	_stats.add_theme_font_size_override("bold_font_size", 17)
	left.add_child(_stats)

	_rewards = _stats.duplicate()
	_rewards.name = "Rewards"
	side.add_child(_rewards)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_add_button(buttons, "PlayAgain", "JOGAR DE NOVO", _play_again)
	_add_button(buttons, "Menu", "MENU", _go_menu)

	EventBus.match_state_changed.connect(_on_state)


func _unhandled_input(event: InputEvent) -> void:   # Passo 128: ESC / botão voltar do Android = MENU
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if Time.get_ticks_msec() - _shown_msec >= BACK_DELAY_MSEC:
			_go_menu()


func _play_again() -> void:
	if Services.match_def != null and Services.match_def.tutorial:   # Passo 106: depois do treino, o próximo é o planeta de verdade
		Services.match_def = PlanetDef.by_id(str(Profile.data.get("planet", "medio")))
	get_tree().reload_current_scene()


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
	if button_name == "PlayAgain":
		button.theme_type_variation = "PrimaryButton"   # a ação principal é a única âmbar
	parent.add_child(button)


# TALLY = a apuração; RESULTS = a tela (cap. 04: o painel só aparece depois da contagem e do replay).
func _on_state(state: int) -> void:
	if state == MatchFlow.State.TALLY:
		_tally()
	elif state == MatchFlow.State.RESULTS:
		_rewards.text = _rewards_text()   # a concessão já aconteceu na apuração
		_panel.visible = true
		_shown_msec = Time.get_ticks_msec()
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
		"Eventos globais: %d — escapou de %d, atingido por %d" % [stats.events_seen(), stats.events_seen() - stats.events_hit(), stats.events_hit()],
	])


func _rewards_text() -> String:
	var rewards := Services.rewards
	if rewards == null or rewards.last.is_empty():
		return ""
	var last: Dictionary = rewards.last
	var lines: PackedStringArray = ["[center][b]RECOMPENSAS[/b][/center]",
			"+%d XP   +%d moedas" % [last["xp"], last["coins"]],
			"Nível %d" % last["level"] + ("  — SUBIU DE NÍVEL!" if last["level"] > last["level_before"] else "")]
	if int(last.get("comeback_xp", 0)) > 0:   # Passo 141 (DD-180)
		lines.append("Bem-vindo de volta! +%d XP" % last["comeback_xp"])
	if int(last.get("streak_coins", 0)) > 0:   # Passo 142 (DD-181)
		lines.append("%d vitórias seguidas: +%d moedas" % [last["streak"], last["streak_coins"]])
	if int(last.get("first_win_coins", 0)) > 0:   # Passo 135 (DD-174)
		lines.append("1ª vitória do dia: +%d moedas" % last["first_win_coins"])
	lines.append(Leagues.result_line(int(last.get("rating_before", last.get("rating", 0))), int(last.get("rating", 0))))   # Passo 122 (DD-162)
	if int(last.get("promo_gems", 0)) > 0:   # Passo 139 (DD-178)
		lines.append("Bônus de promoção: +%d gemas" % last["promo_gems"])
	lines.append(SeasonPass.result_line(int(last.get("pass_before", 0))))   # Passo 123 (DD-163)
	if int(last.get("gems", 0)) > 0:
		lines.append("+%d gemas" % last["gems"])
	# Passo 132: quem volta depois do update pode ganhar várias de uma vez; os que dão título vêm primeiro e o resto
	# vira "+N" (senão o painel estoura os 540 px do celular deitado).
	var titled := {}
	for title_id: String in last.get("new_titles", []):
		titled[Cosmetics.achievement_of(Cosmetics.entry(title_id, "title"))] = true
	var fresh: Array = last.get("new_achievements", []).duplicate()
	fresh.sort_custom(func(a: String, b: String) -> bool: return titled.has(a) and not titled.has(b))
	for id: String in fresh.slice(0, MAX_ACHIEVEMENT_LINES):
		lines.append("CONQUISTA: [b]%s[/b]%s" % [Achievements.title_of(id), " — TÍTULO NOVO" if titled.has(id) else ""])
	if fresh.size() > MAX_ACHIEVEMENT_LINES:
		lines.append("+%d conquistas (veja no perfil)" % (fresh.size() - MAX_ACHIEVEMENT_LINES))
	var ready := 0   # Passo 116 (DD-156): quanto da missão do dia a partida já adiantou (o resgate é no menu)
	for m: Array in DailyMissions.todays():
		ready += 1 if DailyMissions.is_done(m) else 0
	lines.append("Missões do dia: %d/%d%s" % [ready, DailyMissions.todays().size(),
			"  — resgate no menu" if DailyMissions.claimable() > 0 else ""])
	return "\n".join(lines)


func _name(owner_id: int) -> String:
	return "[b]VOCÊ[/b]" if owner_id == Civilization.PLAYER_ID else "Civilização %d" % owner_id


func _percent(fraction: float) -> String:
	return ("%.1f%%" % (fraction * 100.0)).replace(".", ",")
