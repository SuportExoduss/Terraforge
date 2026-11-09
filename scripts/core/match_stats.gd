class_name MatchStats
extends Node
## Apuração (cap. 03, parte 11): conta, por civilização, o que cada uma fez na partida — só ouvindo o EventBus.
## Chaves: loops (áreas conquistadas = circuitos que renderam >= 12 células), converted (fração do planeta tomada de outros),
## cuts (rastros cortados), kills (eliminações por corte). Quem precisa de um número consulta Services.stats.
## Também guarda o domínio (fração do planeta) atual e o auge de cada civilização e quem foi eliminado: ranking().
## ponytail: sem histórico no tempo (o replay guarda o seu); eliminação por evento global não credita ninguém.

const KEYS := ["loops", "converted", "cuts", "kills"]
const MIN_LOOP_CELLS := 12   # abaixo disso o circuito não conta como "área conquistada"

var _stats := {}   # id -> {chave: valor}
var _latest := {}       # id -> domínio atual (fração)
var _peak := {}         # id -> maior domínio já visto
var _eliminated := {}   # id -> true


func _ready() -> void:
	Services.stats = self
	EventBus.territory_loop_claimed.connect(func(id: int, new_cells: int) -> void:
		if new_cells >= MIN_LOOP_CELLS:   # item 2 (DD-127): circuito "vazio" não é área conquistada
			_bump(id, "loops", 1))
	EventBus.territory_cells_converted.connect(func(id: int, fraction: float) -> void: _bump(id, "converted", fraction))
	EventBus.trail_cut.connect(func(_victim: int, attacker: int) -> void: _bump(attacker, "cuts", 1))
	EventBus.civilization_killed.connect(func(_victim: int, killer: int) -> void: _bump(killer, "kills", 1))
	EventBus.territory_score_changed.connect(func(id: int, fraction: float) -> void:
		_latest[id] = fraction
		_peak[id] = maxf(_peak.get(id, 0.0), fraction))
	EventBus.civilization_eliminated.connect(func(id: int) -> void: _eliminated[id] = true)


func _exit_tree() -> void:
	if Services.stats == self:
		Services.stats = null


func get_stat(civilization_id: int, key: String) -> float:
	return _stats.get(civilization_id, {}).get(key, 0.0)


func dominance(civilization_id: int) -> float:
	return _latest.get(civilization_id, 0.0)


func peak(civilization_id: int) -> float:
	return _peak.get(civilization_id, 0.0)


func is_eliminated(civilization_id: int) -> bool:
	return _eliminated.has(civilization_id)


## Ids por colocação: quem ficou vivo pelo domínio final, depois os eliminados pelo auge que atingiram.
func ranking() -> Array:
	var alive: Array = _latest.keys().filter(func(id: int) -> bool: return not _eliminated.has(id))
	alive.sort_custom(_before)
	var fallen: Array = _eliminated.keys()
	fallen.sort_custom(func(a: int, b: int) -> bool: return _peak.get(a, 0.0) > _peak.get(b, 0.0))
	return alive + fallen


## Item 11: domínio igual desempata por mais áreas conquistadas, depois mais cortes, depois o menor id (sempre determinístico).
func _before(a: int, b: int) -> bool:
	for score in [_latest[a] - _latest[b], get_stat(a, "loops") - get_stat(b, "loops"), get_stat(a, "cuts") - get_stat(b, "cuts")]:
		if score != 0.0:
			return score > 0.0
	return a < b


func _bump(civilization_id: int, key: String, amount: float) -> void:
	if not _stats.has(civilization_id):
		_stats[civilization_id] = {}
	_stats[civilization_id][key] = _stats[civilization_id].get(key, 0.0) + amount
