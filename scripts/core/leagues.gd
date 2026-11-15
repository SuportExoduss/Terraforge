extends RefCounted
## Ligas (Passo 122, DD-162): faixas de nome e cor sobre a Habilidade (Profile.rating) que já sobe/desce por colocação.
## Só apresentação e meta de longo prazo: a Habilidade continua sendo o único número; liga nenhuma muda regra de partida.
## Faixas largas no começo (Bronze -> Prata em ~4 vitórias, gancho de novato) e mais largas depois (Diamante -> Lenda ~12 vitórias).
## Sem class_name de propósito (use `const Leagues := preload("res://scripts/core/leagues.gd")`).
## ponytail: só nome/cor/limite; ranking global e temporadas (reset suave) entram quando houver servidor.

# [nome, habilidade mínima, cor do texto]
const TIERS := [
	["Bronze", 0, Color(0.85, 0.55, 0.32)],
	["Prata", 1100, Color(0.80, 0.84, 0.90)],
	["Ouro", 1300, Color(1.0, 0.80, 0.28)],
	["Platina", 1550, Color(0.45, 0.86, 0.84)],
	["Diamante", 1800, Color(0.55, 0.76, 1.0)],
	["Lenda", 2100, Color(0.86, 0.58, 1.0)],
]


## Índice da liga (0 = Bronze) para essa habilidade.
static func index_of(rating: int) -> int:
	var found := 0
	for i in TIERS.size():
		if rating >= int(TIERS[i][1]):
			found = i
	return found


static func name_of(rating: int) -> String:
	return TIERS[index_of(rating)][0]


static func color_of(rating: int) -> Color:
	return TIERS[index_of(rating)][2]


## Pontos que faltam para a próxima liga (0 na última).
static func to_next(rating: int) -> int:
	var i := index_of(rating)
	return 0 if i >= TIERS.size() - 1 else int(TIERS[i + 1][1]) - rating


## Quanto da faixa atual já foi andado (0..1); a última liga sempre 1.
static func progress(rating: int) -> float:
	var i := index_of(rating)
	if i >= TIERS.size() - 1:
		return 1.0
	var start := int(TIERS[i][1])
	return clampf(float(rating - start) / float(int(TIERS[i + 1][1]) - start), 0.0, 1.0)


## Linha para a tela de resultados: "Habilidade 1025 (+25)  ·  Bronze" e, na linha de baixo, "Faltam 75 para Prata", com PROMOVIDO / CAIU quando a liga muda.
static func result_line(before: int, after: int) -> String:
	var delta := after - before
	var line := "Habilidade %d (%s%d)" % [after, "+" if delta >= 0 else "−", absi(delta)]
	var lb := index_of(before)
	var la := index_of(after)
	if la > lb:
		return line + "\n[b]PROMOVIDO: Liga %s![/b]" % TIERS[la][0]
	if la < lb:
		return line + "\nCaiu para a Liga %s" % TIERS[la][0]
	var need := to_next(after)
	return line + "  ·  %s" % TIERS[la][0] + ("" if need == 0 else "\nFaltam %d para %s" % [need, TIERS[la + 1][0]])
