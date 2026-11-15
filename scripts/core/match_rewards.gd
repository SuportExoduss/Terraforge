class_name MatchRewards
extends Node
## Recompensas (cap. 03, parte 11; DD-038): na apuração (TALLY) transforma o desempenho do jogador em XP e moedas
## e grava no perfil salvo. Só lê o placar da partida (Services.stats) — nada aqui é comprável (sem pay-to-win).
## Também concede as conquistas (Achievements) cumpridas nesta partida.
## ponytail: o GDMD não fixa valores, então são constantes provisórias para balancear depois; sem passe de batalha.

const DailyMissions := preload("res://scripts/core/daily_missions.gd")

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

	var xp := XP_PARTICIPATION + loops * XP_PER_LOOP + cuts * XP_PER_CUT + kills * XP_PER_KILL \
			+ roundi(taken * 100.0 * XP_PER_PERCENT_TAKEN) + (XP_SURVIVED if alive else 0)
	if place >= 1 and place <= XP_PLACE.size():
		xp += XP_PLACE[place - 1]
	var coins := COINS_PARTICIPATION + roundi(percent * 100.0 * COINS_PER_PERCENT) + (COINS_WIN if place == 1 else 0)

	Profile.load_data()
	var level_before := Profile.level()
	var data := Profile.data
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

	# Conquistas: o que o snapshot cumpre menos o que o perfil já tem (guarda o instante em que saiu)
	var snapshot := {"loops": loops, "converted": taken, "cuts": cuts, "kills": kills, "percent": percent,
			"alive": 1 if alive else 0, "won": 1 if place == 1 else 0, "matches": data["matches"]}
	var known: Dictionary = data["achievements"]
	var fresh := Achievements.earned(snapshot).filter(func(id: String) -> bool: return not known.has(id))
	var gems: int = fresh.size() * GEMS_PER_ACHIEVEMENT   # Passo 108 (DD-148): GEMAS vêm de conquistas novas (e, depois, de missões e do passe)
	data["gems"] = int(data.get("gems", 0)) + gems
	for id: String in fresh:
		known[id] = Time.get_unix_time_from_system()
	DailyMissions.record(snapshot)   # Passo 115 (DD-155): a partida também avança as missões do dia
	Profile.save()
	last = {"xp": xp, "coins": coins, "gems": gems, "level_before": level_before, "level": Profile.level(), "place": place,
			"percent": percent, "new_achievements": fresh, "rating_before": rating_before, "rating": data["rating"]}
