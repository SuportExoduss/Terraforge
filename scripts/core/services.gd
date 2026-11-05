extends Node
## Ponto de encontro entre módulos (autoload "Services"): substitui os Locators/Registries do Unity.
## Quem cria o serviço se registra aqui; quem precisa só consulta. Ninguém referencia ninguém.

var planet: Planet = null          # centro, raio e get_surface_radius
var territory: Object = null       # duck-typed: is_owned_by(id, pos), get_random_unowned_position()
var themes: PlanetThemeRegistry = null   # fichas de bioma por civilização (cor do solo, piso, altura)
var trails: Array = []             # rastros cortáveis (owner_id, points, cut(attacker_id))
var home_bases: Dictionary = {}    # id -> {position: Vector3, radius: float}


func register_trail(trail: Object) -> void:
	if not trails.has(trail):
		trails.append(trail)


func unregister_trail(trail: Object) -> void:
	trails.erase(trail)


func register_home_base(civilization_id: int, position: Vector3, radius: float) -> void:
	home_bases[civilization_id] = {"position": position, "radius": radius}


func unregister_home_base(civilization_id: int) -> void:
	home_bases.erase(civilization_id)
