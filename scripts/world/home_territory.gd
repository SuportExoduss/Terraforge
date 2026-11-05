class_name HomeTerritory
extends Node3D
## O campo de força de uma civilização: reivindica a calota sob o domo ao nascer, registra a base
## (destino de corredores cortados, zona de regeneração) e vigia a posse dela (DD-100): se um
## inimigo dominar o chão da base, ele herda o império e o dono embarca no foguete.
## Nó com um filho "Civilization".
## ponytail: sem a nave (descida de abertura, voo e realocação, DD-096/DD-100) — entra na etapa 6,
## junto da partida. Até lá, base que cai fica caída.

const OWNERSHIP_CHECK_INTERVAL := 0.5   # vistoria barata e suficiente

@export var dome_radius: float = 7.5    # Unity: domo com escala 15 -> raio 7,5

var ruined := false   # DD-122: dono eliminado; a base segue de pé e capturável

var _civilization: Civilization
var _clock := 0.0
var _active := false


func _ready() -> void:
	_civilization = get_node_or_null("Civilization") as Civilization
	if _civilization == null:
		push_error("[HomeTerritory] %s precisa de um filho Civilization." % name)
		set_process(false)
		return
	EventBus.civilization_eliminated.connect(_on_eliminated)
	var planet := Services.planet
	if not planet.surface_ready:
		await planet.surface_became_ready
	_establish(planet)


func _exit_tree() -> void:
	if _civilization != null:
		Services.unregister_home_base(_civilization.id)


func _process(delta: float) -> void:
	if not _active:
		return
	_clock += delta
	if _clock < OWNERSHIP_CHECK_INTERVAL:
		return
	_clock = 0.0
	var territory := Services.territory
	if territory.is_owned_by(_civilization.id, global_position):
		return
	# DD-100: quem tomou a base herda o império inteiro; o derrotado embarca na hora.
	var conqueror: int = territory.get_owner_at(global_position)
	if conqueror != 0:
		territory.convert_all_cells_of(_civilization.id, conqueror)
		print("[World] Civilização %d tomou a base e HERDOU o império da civilização %d!" % [
				conqueror, _civilization.id])
	_active = false
	EventBus.base_fallen.emit(_civilization.id, conqueror)
	if ruined:
		Services.unregister_home_base(_civilization.id)   # ruína conquistada: o império morto tem novo dono (DD-122)


# Assenta a base na superfície REAL (vales e morros), em pé, e reivindica a calota sob o domo.
func _establish(planet: Planet) -> void:
	var up := (global_position - planet.center).normalized()
	global_position = planet.center + up * planet.get_surface_radius(up)
	var forward := Vector3.FORWARD.slide(up)
	if forward.length_squared() < 0.001:
		forward = Vector3.RIGHT.slide(up)
	global_transform.basis = Basis.looking_at(forward.normalized(), up, true)

	var cap_angle := asin(clampf(dome_radius / planet.radius, 0.0, 1.0))
	Services.territory.claim_cap(_civilization.id, up, cap_angle)
	Services.register_home_base(_civilization.id, global_position, dome_radius)
	_active = true


func _on_eliminated(eliminated_id: int) -> void:
	if eliminated_id == _civilization.id:
		ruined = true
