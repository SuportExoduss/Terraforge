extends MenuScreen
## Tela do passe de temporada (Passo 123, DD-163): nível atual com barra de progresso, as recompensas prontas (RESGATAR) e as
## próximas 3. Só lê/gasta pelo SeasonPass; nada aqui muda a regra da partida. Sem class_name (use preload).

const SeasonPass := preload("res://scripts/core/season_pass.gd")
const UPCOMING := 3   # quantas recompensas futuras aparecem abaixo das prontas


func _init() -> void:
	title_text = "PASSE DA TEMPORADA"


func build(parent: VBoxContainer) -> void:
	var reached := SeasonPass.tiers_reached()
	var total := SeasonPass.TRACK.size()
	var head := make_label("Nível %d de %d" % [reached, total], 28, "Level")
	head.theme_type_variation = "TitleLabel"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(head)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.max_value = SeasonPass.TIER_XP
	bar.value = SeasonPass.xp_in_tier() if reached < total else SeasonPass.TIER_XP
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 16.0)
	parent.add_child(bar)
	var hint := make_label("Passe completo! Temporada nova em breve." if reached >= total
			else "%d / %d XP para o nível %d  ·  cada partida rende XP" % [SeasonPass.xp_in_tier(), SeasonPass.TIER_XP, reached + 1], 15, "Hint")
	hint.theme_type_variation = "DimLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(hint)
	var shown := 0
	for tier in range(1, total + 1):
		var ready := tier <= reached and not SeasonPass.is_claimed(tier)
		if ready or (tier > reached and shown < UPCOMING):
			_add_card(parent, tier, ready)
			if not ready:
				shown += 1
	var foot := make_label("Trilha grátis: moedas, gemas e itens exclusivos do passe. Só aparência.", 15, "Foot")
	foot.theme_type_variation = "DimLabel"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(foot)


func _add_card(parent: VBoxContainer, tier: int, ready: bool) -> void:
	var card := PanelContainer.new()
	card.name = "T_%d" % tier
	card.add_theme_stylebox_override("panel", UiTheme.card(SeasonPass.reward_color(tier), ready))   # pronta = borda âmbar
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(make_label("Nível %d" % tier, 14, "Tier"))
	col.add_child(make_label(SeasonPass.reward_text(tier), 20, "Reward"))
	var button := Button.new()
	button.name = "Claim"
	button.custom_minimum_size = Vector2(190.0, 52.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = "RESGATAR" if ready else "BLOQUEADO"
	button.disabled = not ready
	if ready:
		button.theme_type_variation = "PrimaryButton"
	button.pressed.connect(func():
		if SeasonPass.claim(tier):
			_refresh())
	row.add_child(button)


## Remonta o corpo depois de resgatar.
func _refresh() -> void:
	for child in body.get_children():
		body.remove_child(child)   # sai já, para os cartões novos herdarem os mesmos nomes
		child.queue_free()
	build(body)
	for button in body.find_children("Claim", "Button", true, false):
		if not button.disabled:
			button.grab_focus()
			return
	back.grab_focus()
