class_name MatchRewards
extends Node
## Recompensas (cap. 03, parte 11; DD-038): na apuração (TALLY) transforma o desempenho do jogador em XP e moedas
## e grava no perfil salvo. Só lê o placar da partida (Services.stats) — nada aqui é comprável (sem pay-to-win).
## Também concede as conquistas (Achievements) cumpridas nesta partida.
## ponytail: o GDMD não fixa valores, então são constantes provisórias para balancear depois; sem passe de batalha.

const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const SeasonPass := preload("res://scripts/core/season_pass.gd")
const Leagues := preload("res://scripts/core/leagues.gd")

const XP_PARTICIPATION := 50
const XP_PLACE := [100, 50, 25]     # 1º, 2º e 3º lugar
const XP_PER_LOOP := 2              # por área conquistada
const XP_PER_CUT := 5               # por rastro cortado
const XP_PER_KILL := 25             # por eliminação
const XP_PER_PERCENT_TAKEN := 3     # por 1% do planeta tomado de rivais
const XP_SURVIVED := 25
const COINS_PARTICIPATION := 10
const COINS_PER_PERCENT := 1        # por 1% do planeta no fim
const COINS_WIN := 25
const FIRST_WIN_COINS := DailyMissions.FIRST_WIN_COINS   # Passo 135 (DD-174): bônus da 1ª vitória do dia (só moedas, sem poder)
const COMEBACK_DAYS := 3             # Passo 141 (DD-180): longe há 3 dias ou mais...
const COMEBACK_XP := 60              # ...a próxima partida rende XP a mais (só XP, sem moeda nem poder)
const STREAK_COINS := 5              # Passo 142 (DD-181): a partir da 2ª vitória seguida, +5 moedas por vitória já encadeada...
const STREAK_MAX := 5                # ...até +25 (só moedas, sem poder; qualquer não-vitória zera)
const GEMS_PER_ACHIEVEMENT := 5      # Passo 108 (DD-148): a GEMA é a moeda rara; por ora vem só de conquistas novas

var last := {}   # recompensa desta partida: xp, coins, level_before, level, place, percent

var _done := false


func _ready() -> void:
	Services.rewards = self
	EventBus.match_state_changed.connect(_on_state)


func _exit_tree() -> void:
	if Services.rewards == self:
		Services.rewards = null


func _on_state(state: int) -> void:
	if state == MatchFlow.State.TALLY and not _done:
		_grant()


func _grant() -> void:
	var stats := Services.stats
	if stats == null:
		return
	_done = true
	var me := Civilization.PLAYER_ID
	var place: int = stats.ranking().find(me) + 1   # 0 = nunca pontuou
	var percent: float = stats.dominance(me)
	var alive: bool = not stats.is_eliminated(me)
	var loops := int(stats.get_stat(me, "loops"))
	var cuts := int(stats.get_stat(me, "cuts"))
	var kills := int(stats.get_stat(me, "kills"))
	var taken: float = stats.get_stat(me, "converted")
	var sprints := int(stats.get_stat(me, "sprints"))
	var abilities := int(stats.get_stat(me, "abilities"))
	var captures := int(stats.get_stat(me, "captures"))

	var xp := XP_PARTICIPATION + loops * XP_PER_LOOP + cuts * XP_PER_CUT + kills * XP_PER_KILL \
			+ roundi(taken * 100.0 * XP_PER_PERCENT_TAKEN) + (XP_SURVIVED if alive else 0)
	if place >= 1 and place <= XP_PLACE.size():
		xp += XP_PLACE[place - 1]
	var coins := COINS_PARTICIPATION + roundi(percent * 100.0 * COINS_PER_PERCENT) + (COINS_WIN if place == 1 else 0)

	Profile.load_data()
	var comeback := COMEBACK_XP if Profile.days_away(DailyMissions.today()) >= COMEBACK_DAYS else 0   # Passo 141 (DD-180)
	xp += comeback
	var level_before := Profile.level()
	var pass_before := SeasonPass.tiers_reached()
	var data := Profile.data
	var first_win: bool = place == 1 and DailyMissions.first_win_ready()   # Passo 135 (DD-174)
	if first_win:
		coins += FIRST_WIN_COINS
		data["first_win_day"] = DailyMissions.today()
	var streak: int = int(data.get("win_streak", 0)) + 1 if place == 1 else 0   # Passo 142 (DD-181)
	data["win_streak"] = streak
	var streak_coins: int = STREAK_COINS * mini(streak - 1, STREAK_MAX) if streak >= 2 else 0
	coins += streak_coins
	data["xp"] += xp
	data["coins"] += coins
	data["matches"] += 1
	data["wins"] += 1 if place == 1 else 0
	data["best_percent"] = maxf(data["best_percent"], percent)
	data["loops"] += loops
	data["cuts"] += cuts
	data["kills"] += kills
	var rating_before := int(data["rating"])
	data["rating"] = Profile.rating_after(rating_before, place)
	var promo := Leagues.promotion_gems(int(data["league_best"]), int(data["rating"]))   # Passo 139 (DD-178)
	data["league_best"] = maxi(int(data["league_best"]), Leagues.index_of(int(data["rating"])))
	data["gems"] = int(data.get("gems", 0)) + promo
	Profile.add_history(DailyMissions.today(), place, percent, int(data["rating"]) - rating_before)   # Passo 137 (DD-176)

	# Conquistas: o que o snapshot cumpre menos o que o perfil já tem (guarda o instante em que saiu)
	var snapshot := {"loops": loops, "converted": taken, "cuts": cuts, "kills": kills, "percent": percent,
			"alive": 1 if alive else 0, "won": 1 if place == 1 else 0, "matches": data["matches"],
			"total_wins": data["wins"], "total_loops": data["loops"], "total_cuts": data["cuts"], "total_kills": data["kills"],
			"level": Profile.level(), "rating": data["rating"],   # Passo 132: a carreira também conta
			"sprints": sprints, "abilities": abilities, "captures": captures}   # Passo 149 (DD-188)
	var known: Dictionary = data["achievements"]
	var fresh := Achievements.earned(snapshot).filter(func(id: String) -> bool: return not known.has(id))
	var gems: int = fresh.size() * GEMS_PER_ACHIEVEMENT   # Passo 108 (DD-148): GEMAS vêm de conquistas novas (e, depois, de missões e do passe)
	data["gems"] = int(data.get("gems", 0)) + gems
	var titles := []   # Passo 132 (DD-170): algumas conquistas dão um título de perfil
	for id: String in fresh:
		known[id] = Time.get_unix_time_from_system()
		for item: Array in Cosmetics.items("title"):
			if Cosmetics.achievement_of(item) == id and Cosmetics.grant(item[0], "title"):
				titles.append(item[0])
	DailyMissions.record(snapshot)   # Passo 115 (DD-155): a partida também avança as missões do dia
	SeasonPass.add_xp(xp)   # Passo 123 (DD-163): e o passe de temporada (mesmo XP da partida)
	Profile.save()
	last = {"xp": xp, "coins": coins, "gems": gems, "level_before": level_before, "level": Profile.level(), "place": place,
			"percent": percent, "new_achievements": fresh, "new_titles": titles, "rating_before": rating_before, "rating": data["rating"], "pass_before": pass_before,
			"first_win_coins": FIRST_WIN_COINS if first_win else 0, "promo_gems": promo, "comeback_xp": comeback,
			"streak": streak, "streak_coins": streak_coins}
