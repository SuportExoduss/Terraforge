class_name MissionsScreen
extends MenuScreen
## Tela de missões diárias (Passo 115, DD-155): a sequência de dias e as 3 missões de hoje, cada uma com barra de progresso e
## RESGATAR (moedas). Só lê/gasta pelo DailyMissions; nada aqui muda a regra da partida.

const DailyMissions := preload("res://scripts/core/daily_missions.gd")


func _init() -> void:
	title_text = "MISSÕES"


func build(parent: VBoxContainer) -> void:
	_add_gift(parent)   # Passo 140 (DD-179): o presente do dia, no alto
	var streak := DailyMissions.streak_days()
	var head := "Sequência: %d %s" % [streak, "dia" if streak == 1 else "dias"] if streak > 0 			else "Resgate uma missão hoje para começar a sequência"
	var streak_label := make_label(head, 26 if streak > 0 else 18, "Streak")
	streak_label.theme_type_variation = "TitleLabel"
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(streak_label)
	var prize := make_label("%d gemas no dia %d da sequência (faltam %d)" % [DailyMissions.STREAK_GEMS,
			(floori(float(streak) / DailyMissions.STREAK_PERIOD) + 1) * DailyMissions.STREAK_PERIOD, DailyMissions.days_to_streak_prize()], 15, "StreakPrize")
	prize.theme_type_variation = "DimLabel"
	prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(prize)
	for m: Array in DailyMissions.todays():
		_add_card(parent, m)
	_add_card(parent, DailyMissions.WEEKLY, true)   # Passo 136 (DD-175): a meta da semana, em gemas
	var all_done: bool = DailyMissions.state()["claimed"].size() >= DailyMissions.todays().size()
	var foot := make_label("As 3 resgatadas hoje: +%d gema  ✓" % DailyMissions.ALL_BONUS_GEMS if all_done
			else "Resgate as 3 do dia e ganhe +%d gema. Missões novas à meia-noite." % DailyMissions.ALL_BONUS_GEMS, 15, "Foot")
	foot.theme_type_variation = "DimLabel"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(foot)
	var first := make_label("Ganhe uma partida hoje: +%d moedas (1ª vitória do dia)" % DailyMissions.FIRST_WIN_COINS if DailyMissions.first_win_ready()
			else "1ª vitória do dia: ✓", 15, "FirstWin")   # Passo 135 (DD-174)
	first.theme_type_variation = "DimLabel"
	first.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(first)


## Passo 140: calendário de 7 presentes; o de hoje tem botão PEGAR, os dias já pegos ficam marcados.
func _add_gift(parent: VBoxContainer) -> void:
	var ready := DailyMissions.gift_ready()
	var slot := DailyMissions.gift_slot()
	var card := PanelContainer.new()
	card.name = "Gift"
	card.add_theme_stylebox_override("panel", UiTheme.card(Color(1.0, 0.8, 0.3), ready))
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var title := make_label("Presente do dia  ·  dia %d de %d" % [slot + 1, DailyMissions.GIFT_COINS.size()], 20, "GiftTitle")
	title.theme_type_variation = "TitleLabel"
	col.add_child(title)
	var days := HBoxContainer.new()
	days.name = "GiftDays"
	days.add_theme_constant_override("separation", 6)
	col.add_child(days)
	for i in DailyMissions.GIFT_COINS.size():
		var chip := make_label("%s%d" % ["✓ " if i < slot or (i == slot and not ready) else "", int(DailyMissions.GIFT_COINS[i])], 15, "Day%d" % i)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.modulate = Color(1.0, 0.85, 0.4) if i == slot else Color(1.0, 1.0, 1.0, 0.55)
		days.add_child(chip)
	var button := Button.new()
	button.name = "GiftClaim"
	button.custom_minimum_size = Vector2(0.0, 52.0)
	var prize := "%d moedas" % int(DailyMissions.GIFT_COINS[slot]) + (" + %d gemas" % DailyMissions.GIFT_GEMS if slot == DailyMissions.GIFT_COINS.size() - 1 else "")
	button.text = ("PEGAR  +" + prize) if ready else "PEGO ✓  ·  volte amanhã"
	button.disabled = not ready
	if ready:
		button.theme_type_variation = "PrimaryButton"
	button.pressed.connect(func():
		if DailyMissions.gift_claim():
			_refresh())
	col.add_child(button)


func _add_card(parent: VBoxContainer, m: Array, weekly := false) -> void:
	var done := DailyMissions.weekly_done() if weekly else DailyMissions.is_done(m)
	var claimed := DailyMissions.weekly_claimed() if weekly else DailyMissions.is_claimed(m)
	var reward := "%d gemas" % int(m[4]) if weekly else "%d moedas" % int(m[4])
	var card := PanelContainer.new()
	card.name = "M_" + String(m[0])
	card.add_theme_stylebox_override("panel", UiTheme.card(Color(0.4, 0.7, 1.0), done and not claimed))   # pronta = borda âmbar
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := make_label(m[1], 20, "Text")
	title.modulate = Color(1.0, 1.0, 1.0, 0.55) if claimed else Color.WHITE
	col.add_child(title)
	var have := DailyMissions.weekly_wins() if weekly else mini(DailyMissions.progress_of(m), int(m[3]))
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.max_value = int(m[3])
	bar.value = have
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 14.0)
	col.add_child(bar)
	col.add_child(make_label("%d / %d" % [have, int(m[3])], 14, "Count"))
	var button := Button.new()
	button.name = "Claim"
	button.custom_minimum_size = Vector2(190.0, 52.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = "RESGATADA ✓" if claimed else ("RESGATAR  +%d" % int(m[4]) + (" gemas" if weekly else "") if done else "+" + reward)
	button.disabled = claimed or not done
	if done and not claimed:
		button.theme_type_variation = "PrimaryButton"
	button.pressed.connect(func():
		if DailyMissions.weekly_claim() if weekly else DailyMissions.claim(m[0]):
			_refresh())
	row.add_child(button)


## Remonta o corpo (progresso e botões) depois de resgatar.
func _refresh() -> void:
	for child in body.get_children():
		body.remove_child(child)   # sai já, para os cartões novos herdarem os mesmos nomes
		child.queue_free()
	build(body)
	for button in body.find_children("*Claim", "Button", true, false):
		if not button.disabled:
			button.grab_focus()
			return
	back.grab_focus()
