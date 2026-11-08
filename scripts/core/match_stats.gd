class_name MatchStats
extends Node
## Apuração (cap. 03, parte 11): conta, por civilização, o que cada uma fez na partida — só ouvindo o EventBus.
## Chaves: loops (áreas conquistadas = circuitos fechados), converted (fração do planeta tomada de outros),
## cuts (rastros cortados), kills (eliminações por corte). Quem precisa de um número consulta Services.stats.
## ponytail: sem histórico no tempo (o replay guarda o seu); eliminação por evento global não credita ninguém.

const KEYS := ["loops", "converted", "cuts", "kills"]

var _stats := {}   # id -> {chave: valor}


func _ready() -> void:
	Services.stats = self
	EventBus.territory_loop_closed.connect(func(id: int, _points: PackedVector3Array) -> void: _bump(id, "loops", 1))
	EventBus.territory_cells_converted.connect(func(id: int, fraction: float) -> void: _bump(id, "converted", fraction))
	EventBus.trail_cut.connect(func(_victim: int, attacker: int) -> void: _bump(attacker, "cuts", 1))
	EventBus.civilization_killed.connect(func(_victim: int, killer: int) -> void: _bump(killer, "kills", 1))


func _exit_tree() -> void:
	if Services.stats == self:
		Services.stats = null


func get_stat(civilization_id: int, key: String) -> float:
	return _stats.get(civilization_id, {}).get(key, 0.0)


func _bump(civilization_id: int, key: String, amount: float) -> void:
	if not _stats.has(civilization_id):
		_stats[civilization_id] = {}
	_stats[civilization_id][key] = _stats[civilization_id].get(key, 0.0) + amount
