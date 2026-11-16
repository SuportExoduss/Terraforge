class_name Achievements
extends RefCounted
## Conquistas (cap. 03 parte 11). Tabela única: [id, nome, descrição, chave, mínimo] — a conquista sai quando
## `snapshot[chave] >= mínimo`. O snapshot junta o placar da partida (loops, converted, cuts, kills, percent, place,
## alive) com o total do perfil (matches e, no Passo 132, total_wins/total_loops/total_cuts/total_kills, level, rating).
## Valores de balanceamento provisórios.
## ponytail: sem raridade, ícones nem progresso parcial; só nome + descrição.

const LIST := [
	["first_area", "Primeira Conquista", "Feche 1 área com o rastro", "loops", 1],
	["cartographer", "Cartógrafo", "Feche 10 áreas numa partida", "loops", 10],
	["cutter", "Cortador", "Corte 3 rastros rivais numa partida", "cuts", 3],
	["hunter", "Caçador", "Elimine uma civilização cortando o rastro", "kills", 1],
	["usurper", "Usurpador", "Tome 10% do planeta dos rivais numa partida", "converted", 0.10],
	["survivor", "Sobrevivente", "Termine a partida sem ser eliminado", "alive", 1],
	["conqueror", "Conquistador", "Termine em 1º lugar", "won", 1],
	["dominator", "Dominador", "Termine com 50% ou mais do planeta", "percent", 0.50],
	["veteran", "Veterano", "Jogue 10 partidas", "matches", 10],
	# Passo 132 (DD-170): metas de longo prazo (a carreira) e de maestria; algumas rendem um título (Cosmetics, 6º campo)
	["seasoned", "Calejado", "Jogue 50 partidas", "matches", 50],
	["champion", "Campeão", "Vença 5 partidas", "total_wins", 5],
	["legend", "Lenda Viva", "Vença 25 partidas", "total_wins", 25],
	["builder", "Construtor", "Feche 100 áreas no total", "total_loops", 100],
	["scissors", "Tesoura Afiada", "Corte 50 rastros rivais no total", "total_cuts", 50],
	["exterminator", "Exterminador", "Elimine 10 civilizações no total", "total_kills", 10],
	["master_cartographer", "Mestre Cartógrafo", "Feche 25 áreas numa partida", "loops", 25],
	["unbeatable", "Imbatível", "Termine com 75% ou mais do planeta", "percent", 0.75],
	["ascending", "Em Ascensão", "Chegue ao nível 10", "level", 10],
	["platinum", "Platinado", "Chegue à liga Platina", "rating", 1550],   # 1550 = Leagues.TIERS[3]
]


## Ids das conquistas que o snapshot cumpre.
static func earned(snapshot: Dictionary) -> Array:
	var out := []
	for entry: Array in LIST:
		if snapshot.get(entry[3], 0.0) >= entry[4]:
			out.append(entry[0])
	return out


static func description_of(id: String) -> String:
	for entry: Array in LIST:
		if entry[0] == id:
			return entry[2]
	return ""


static func title_of(id: String) -> String:
	for entry: Array in LIST:
		if entry[0] == id:
			return entry[1]
	return id
