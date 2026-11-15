class_name ProfileScreen
extends MenuScreen
## Tela do perfil (Passo 42): nível e barra de XP até o próximo nível, moedas, partidas e totais acumulados e a lista
## de conquistas (feitas em destaque, as outras apagadas). Só lê o Profile; nada aqui altera o jogo.
## ponytail: sem gráfico de histórico nem ranking; só os totais que o perfil já guarda.

const Leagues := preload("res://scripts/core/leagues.gd")


func _init() -> void:
	title_text = "PERFIL"


## XP em que o nível `level` começa (nível N começa em 100·(N-1)² XP, igual ao Profile.level).
static func level_start(level: int) -> int:
	return Profile.XP_PER_LEVEL_STEP * (level - 1) * (level - 1)


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
