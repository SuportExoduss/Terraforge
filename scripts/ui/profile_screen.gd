class_name ProfileScreen
extends MenuScreen
## Tela do perfil (Passo 42): nível e barra de XP até o próximo nível, moedas, partidas e totais acumulados e a lista
## de conquistas (feitas em destaque, as outras apagadas). Só lê o Profile; nada aqui altera o jogo.
## ponytail: sem gráfico nem ranking; só os totais e as últimas partidas (Passo 137) que o perfil já guarda.

const Leagues := preload("res://scripts/core/leagues.gd")
const DailyMissions := preload("res://scripts/core/daily_missions.gd")   # (só o número do dia)


func _init() -> void:
	title_text = "PERFIL"


## XP em que o nível `level` começa (nível N começa em 100·(N-1)² XP, igual ao Profile.level).
static func level_start(level: int) -> int:
	return Profile.XP_PER_LEVEL_STEP * (level - 1) * (level - 1)


## "Hoje  ·  1º lugar  ·  34% do planeta  ·  +25" (colocação 0 = nunca pontuou; dia em número do calendário, o JSON devolve float).
static func history_line(entry: Dictionary) -> String:
	var ago: int = DailyMissions.today() - int(entry.get("day", 0))
	var when := "Hoje" if ago <= 0 else ("Ontem" if ago == 1 else "Há %d dias" % ago)
	var place := int(entry.get("place", 0))
	var delta := int(entry.get("delta", 0))
	return "%s  ·  %s  ·  %d%% do planeta  ·  %s%d" % [when, "%dº lugar" % place if place > 0 else "Sem pontuar",
			roundi(float(entry.get("percent", 0.0)) * 100.0), "+" if delta >= 0 else "−", absi(delta)]


func build(parent: VBoxContainer) -> void:
	var data := Profile.data
	var level := Profile.level()
	var start := level_start(level)
	var next := level_start(level + 1)
	# Passo 120: nível+habilidade numa linha e barra+XP na outra, para o cartão caber em 540 px (VOLTAR não some)
	var head := HBoxContainer.new()
	head.name = "Head"
	var level_label := make_label("Nível %d" % level, 28, "Level")
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(level_label)
	var points := int(data["rating"])
	var rating := make_label("Liga %s  ·  %d" % [Leagues.name_of(points), points], 20, "Rating")   # sobe e desce com a colocação (Passos 53 e 122)
	rating.add_theme_color_override("font_color", Leagues.color_of(points))
	rating.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(rating)
	parent.add_child(head)
	var xp_row := HBoxContainer.new()
	xp_row.name = "XpRow"
	xp_row.add_theme_constant_override("separation", 12)
	var bar := ProgressBar.new()
	bar.name = "XpBar"
	bar.min_value = start
	bar.max_value = next
	bar.value = int(data["xp"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 18.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(bar)
	xp_row.add_child(make_label("%d / %d XP para o nível %d" % [int(data["xp"]), next, level + 1], 16, "Xp"))
	parent.add_child(xp_row)
	parent.add_child(make_label("%d moedas  ·  %d partidas  ·  %d vitórias  ·  melhor %d%% do planeta" % [
			int(data["coins"]), int(data["matches"]), int(data["wins"]), roundi(float(data["best_percent"]) * 100.0)], 18, "Totals"))
	parent.add_child(make_label("%d áreas fechadas  ·  %d cortes  ·  %d eliminações" % [
			int(data["loops"]), int(data["cuts"]), int(data["kills"])], 18, "Totals2"))
	parent.add_child(make_label("ÚLTIMAS PARTIDAS", 20, "HistoryTitle"))   # Passo 137 (DD-176)
	var history: Array = data.get("history", [])
	if history.is_empty():
		parent.add_child(make_label("Jogue uma partida para ver o histórico aqui.", 14, "HistoryEmpty"))
	for i in history.size():
		var row := make_label(history_line(history[i]), 14, "H_%d" % i)
		if int(history[i].get("place", 0)) == 1:
			row.modulate = Color(1.0, 0.85, 0.35)   # vitória em destaque, igual às conquistas feitas
		parent.add_child(row)
	parent.add_child(make_label("CONQUISTAS  %d/%d" % [data["achievements"].size(), Achievements.LIST.size()], 20, "AchievementsTitle"))
	var grid := GridContainer.new()
	grid.name = "Achievements"
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 0)
	parent.add_child(grid)
	for entry: Array in Achievements.LIST:
		var done: bool = data["achievements"].has(entry[0])
		var label := make_label("%s  %s — %s" % ["●" if done else "○", entry[1], entry[2]], 14, "A_" + String(entry[0]))
		label.modulate = Color(1.0, 0.85, 0.35) if done else Color(1.0, 1.0, 1.0, 0.45)
		grid.add_child(label)
