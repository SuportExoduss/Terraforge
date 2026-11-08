class_name Achievements
extends RefCounted
## Conquistas (cap. 03 parte 11). Tabela única: [id, nome, descrição, chave, mínimo] — a conquista sai quando
## `snapshot[chave] >= mínimo`. O snapshot junta o placar da partida (loops, converted, cuts, kills, percent, place,
## alive) com o total do perfil (matches). Valores de balanceamento provisórios.
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
]


## Ids das conquistas que o snapshot cumpre.
static func earned(snapshot: Dictionary) -> Array:
	var out := []
	for entry: Array in LIST:
		if snapshot.get(entry[3], 0.0) >= entry[4]:
			out.append(entry[0])
	return out


static func title_of(id: String) -> String:
	for entry: Array in LIST:
		if entry[0] == id:
			return entry[1]
	return id
