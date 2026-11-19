extends RefCounted
## Missões diárias e sequência de dias (Passo 115, DD-155): todo dia o planeta oferece 3 missões — uma fácil, uma média e uma
## difícil — iguais para todos os jogadores naquele dia (sorteadas pelo número do dia). O progresso soma as partidas do dia;
## RESGATAR dá moedas, a 1ª missão resgatada do dia mantém a SEQUÊNCIA (dias seguidos) e as 3 resgatadas dão 1 gema. A cada
## 7 dias de sequência, +5 gemas. Só recompensa de aparência/loja: nada aqui muda a regra da partida (sem pay-to-win, DD-144).
## ponytail: dia = dia local do aparelho (mudar o relógio engana; a versão online usará o relógio do servidor).
## Dados: `Profile.data["daily"] = {day, progress{id: n}, claimed[id]}` e `Profile.data["streak"] = {count, last_day}`.
## Uso (sem class_name, preload): `const DailyMissions := preload("res://scripts/core/daily_missions.gd")`.

const TIERS := [   # por faixa: opções [id, texto, estatística da partida, meta, moedas, soma nas partidas (true) ou melhor partida (false)]
	[["play", "Jogue 2 partidas", "play", 2, 20, true],
			["loops", "Feche 6 áreas", "loops", 6, 25, true]],
	[["cuts", "Corte 2 rastros de rivais", "cuts", 2, 40, true],
			["alive", "Sobreviva até o fim de 2 partidas", "alive", 2, 35, true],
			["percent", "Domine 20% do planeta numa partida", "percent", 20, 40, false]],
	[["kills", "Elimine 1 rival", "kills", 1, 50, true],
			["win", "Vença 1 partida", "won", 1, 60, true]],
]
const ALL_BONUS_GEMS := 1    # as 3 do dia resgatadas
const STREAK_PERIOD := 7     # a cada 7 dias seguidos...
const STREAK_GEMS := 5       # ...ganha 5 gemas

static var day_override := -1   # só para testes: fixa o "dia de hoje"


## Número do dia local (muda à meia-noite do aparelho).
static func today() -> int:
	if day_override >= 0:
		return day_override
	return floori((Time.get_unix_time_from_system() + Time.get_time_zone_from_system().bias * 60.0) / 86400.0)


## As 3 missões de hoje (uma de cada faixa), iguais para quem abrir o jogo no mesmo dia.
static func todays() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = today() * 7919 + 13
	var out := []
	for tier: Array in TIERS:
		out.append(tier[rng.randi() % tier.size()])
	return out


## Estado de hoje no perfil; vira "página em branco" quando o dia muda.
static func state() -> Dictionary:
	var d: Dictionary = Profile.data.get("daily", {})
	if int(d.get("day", -1)) != today():
		d = {"day": today(), "progress": {}, "claimed": []}
		Profile.data["daily"] = d
	return d


static func progress_of(mission: Array) -> int:
	return int(state()["progress"].get(mission[0], 0))


static func is_done(mission: Array) -> bool:
	return progress_of(mission) >= int(mission[3])


static func is_claimed(mission: Array) -> bool:
	return state()["claimed"].has(mission[0])


## Quantas missões estão prontas para resgatar (o aviso do menu).
static func claimable() -> int:
	var n := 0
	for m: Array in todays():
		if is_done(m) and not is_claimed(m):
			n += 1
	if weekly_done() and not weekly_claimed():
		n += 1   # Passo 136: a meta da semana também avisa no menu
	return n


## Chamado pelo MatchRewards ao fechar uma partida (antes de gravar o perfil): soma o que a partida rendeu.
static func record(snapshot: Dictionary) -> void:
	var progress: Dictionary = state()["progress"]
	var week_state := weekly_state()
	week_state["wins"] = int(week_state["wins"]) + int(snapshot.get("won", 0))   # Passo 136
	for m: Array in todays():
		var got := _stat(snapshot, m[2])
		var have := int(progress.get(m[0], 0))
		progress[m[0]] = (have + got) if m[5] else maxi(have, got)


static func _stat(snapshot: Dictionary, key: String) -> int:
	if key == "play":
		return 1
	var v := float(snapshot.get(key, 0))
	return roundi(v * 100.0) if key == "percent" else int(v)


## Resgata a missão `id` (pronta e ainda não resgatada): moedas, sequência e o bônus das 3. Grava o perfil.
static func claim(id: String) -> bool:
	var d := state()
	for m: Array in todays():
		if m[0] != id:
			continue
		if not is_done(m) or is_claimed(m):
			return false
		d["claimed"].append(id)
		Profile.data["coins"] = int(Profile.data["coins"]) + int(m[4])
		var gems := _touch_streak()
		if d["claimed"].size() >= todays().size():
			gems += ALL_BONUS_GEMS
		Profile.data["gems"] = int(Profile.data.get("gems", 0)) + gems
		Profile.save()
		return true
	return false


## Primeiro resgate do dia: continua a sequência (ontem resgatou) ou recomeça em 1. Devolve as gemas do marco de 7 dias.
static func _touch_streak() -> int:
	var s: Dictionary = Profile.data.get("streak", {})
	var day := today()
	var last := int(s.get("last_day", -10))
	if last == day:
		return 0
	var count := (int(s.get("count", 0)) + 1) if last == day - 1 else 1
	Profile.data["streak"] = {"count": count, "last_day": day}
	return STREAK_GEMS if count % STREAK_PERIOD == 0 else 0


## Dias seguidos agora (0 se ontem passou em branco).
static func streak_days() -> int:
	var s: Dictionary = Profile.data.get("streak", {})
	return int(s.get("count", 0)) if int(s.get("last_day", -10)) >= today() - 1 else 0


## Passo 135 (DD-174): a 1ª vitória de cada dia rende moedas a mais (MatchRewards paga); true enquanto hoje ainda não teve uma.
const FIRST_WIN_COINS := 40


static func first_win_ready() -> bool:
	return int(Profile.data.get("first_win_day", -1)) != today()


## Passo 136 (DD-175): META DA SEMANA — vencer 5 partidas de segunda a domingo rende GEMAS (uma vez por semana).
## Dados: `Profile.data["weekly"] = {week, wins, claimed}`; a semana vira na segunda (a mesma conta da oferta da loja).
const WEEKLY := ["week_win", "Vença 5 partidas nesta semana", "won", 5, 3]   # [id, texto, estatística, meta, gemas]


static func week() -> int:
	return floori((today() + 3) / 7.0)


static func weekly_state() -> Dictionary:
	var d: Dictionary = Profile.data.get("weekly", {})
	if int(d.get("week", -1)) != week():
		d = {"week": week(), "wins": 0, "claimed": false}
		Profile.data["weekly"] = d
	return d


static func weekly_wins() -> int:
	return mini(int(weekly_state()["wins"]), int(WEEKLY[3]))


static func weekly_done() -> bool:
	return weekly_wins() >= int(WEEKLY[3])


static func weekly_claimed() -> bool:
	return bool(weekly_state()["claimed"])


## Resgata a meta da semana (pronta e ainda não resgatada): gemas. Grava o perfil.
static func weekly_claim() -> bool:
	if not weekly_done() or weekly_claimed():
		return false
	weekly_state()["claimed"] = true
	Profile.data["gems"] = int(Profile.data.get("gems", 0)) + int(WEEKLY[4])
	Profile.save()
	return true


## Passo 140 (DD-179): PRESENTE DO DIA — abrir a tela de missões e pegar o presente de hoje (sem precisar jogar) rende moedas; 7 dias
## seguidos completam o calendário (o 7º traz também gemas) e ele recomeça. Faltar um dia volta ao dia 1. Só moedas/gemas, sem poder.
## Dados: `Profile.data["gift"] = {count, last_day}` (count = dias seguidos pegos).
const GIFT_COINS := [10, 15, 20, 25, 30, 40, 60]
const GIFT_GEMS := 2   # a mais, no 7º dia


static func gift_ready() -> bool:
	return int(Profile.data.get("gift", {}).get("last_day", -10)) != today()


## Dias seguidos já pegos (0 se ontem passou em branco).
static func gift_run() -> int:
	var g: Dictionary = Profile.data.get("gift", {})
	return int(g.get("count", 0)) if int(g.get("last_day", -10)) >= today() - 1 else 0


## Posição (0..6) no calendário: o presente que está na vez, ou o que acabou de ser pego hoje.
static func gift_slot() -> int:
	return (gift_run() if gift_ready() else gift_run() - 1) % GIFT_COINS.size()


## Pega o presente de hoje (uma vez por dia). Grava o perfil.
static func gift_claim() -> bool:
	if not gift_ready():
		return false
	var slot := gift_slot()
	Profile.data["coins"] = int(Profile.data["coins"]) + int(GIFT_COINS[slot])
	if slot == GIFT_COINS.size() - 1:
		Profile.data["gems"] = int(Profile.data.get("gems", 0)) + GIFT_GEMS
	Profile.data["gift"] = {"count": gift_run() + 1, "last_day": today()}
	Profile.save()
	return true


## O número do aviso do menu: missões prontas + o presente do dia, se ainda não foi pego.
static func badge() -> int:
	return claimable() + (1 if gift_ready() else 0)


## Quantos dias faltam para o próximo prêmio de sequência (1..7).
static func days_to_streak_prize() -> int:
	return STREAK_PERIOD - streak_days() % STREAK_PERIOD
