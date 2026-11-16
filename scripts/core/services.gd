extends Node
## Ponto de encontro entre módulos (autoload "Services"): substitui os Locators/Registries do Unity.
## Quem cria o serviço se registra aqui; quem precisa só consulta. Ninguém referencia ninguém.

var planet: Planet = null          # centro, raio e get_surface_radius
var territory: Object = null       # duck-typed: is_owned_by(id, pos), get_random_unowned_position()
var themes: PlanetThemeRegistry = null   # fichas de bioma por civilização (cor do solo, piso, altura)
var trails: Array = []             # rastros cortáveis (owner_id, points, cut(attacker_id))
var home_bases: Dictionary = {}    # id -> {position: Vector3, radius: float}
var flow: Object = null            # máquina de estados da partida (MatchFlow): state, go(estado)
var stats: Object = null           # apuração da partida (MatchStats): get_stat(id, chave), ranking(), dominance(id)
var rewards: Object = null         # recompensas da partida (MatchRewards): last = XP/moedas concedidos
var match_def: PlanetDef = null    # planeta escolhido no menu (DD-143); null = padrões das cenas (testes, servidor)


func _ready() -> void:
	preload("res://scripts/ui/ui_theme.gd").apply(get_tree())   # Passo 109 (DD-149): uma cara só para todos os menus e o HUD
	preload("res://scripts/core/haptics.gd").connect_events(EventBus)   # Passo 133 (DD-172): vibração nos momentos que importam


func register_trail(trail: Object) -> void:
	if not trails.has(trail):
		trails.append(trail)


func unregister_trail(trail: Object) -> void:
	trails.erase(trail)


func register_home_base(civilization_id: int, position: Vector3, radius: float) -> void:
	home_bases[civilization_id] = {"position": position, "radius": radius}


func unregister_home_base(civilization_id: int) -> void:
	home_bases.erase(civilization_id)
