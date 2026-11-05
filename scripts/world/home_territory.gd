class_name HomeTerritory
extends Node3D
## O campo de força de uma civilização e a nave dela. A partida abre com a nave DESCENDO do espaço (DD-096);
## ao pousar ela reivindica a calota sob o domo e registra a base (destino de corredores cortados, zona de
## regeneração). Se um inimigo dominar o chão da base (DD-100), ele herda o império, o dono embarca, a
## nave decola, VOA em arco e pousa num ponto livre, restabelecendo base + campo de força.
## Nó com um filho "Civilization"; filhos opcionais "Dome" (surge no GO!) e "Ship" (sempre visível).

enum State { OPENING_DESCENT, GROUNDED, COUNTDOWN, FLYING, LANDED }

const OWNERSHIP_CHECK_INTERVAL := 0.5   # vistoria barata e suficiente
const COUNTDOWN_LEAD_SECONDS := 3.0     # DD-100: contagem na tela = 3 s finais de voo + 2 s de nave pousada
const MAX_POLE_SIN := 0.8               # pouso nunca nos polos (a mais de ~53° do equador)

@export var dome_radius: float = 7.5    # Unity: domo com escala 15 -> raio 7,5
@export var opening_seconds := 5.0      # DD-096: descida de abertura
@export var opening_altitude := 60.0
@export var relocation_delay_seconds := 0.2   # DD-100: decola quase na hora
@export var flight_seconds := 4.0
@export var flight_altitude := 30.0
@export var landed_wait_seconds := 2.0

var ruined := false   # DD-122: dono eliminado; a base segue de pé e capturável
var state := State.OPENING_DESCENT

var _civilization: Civilization
var _clock := 0.0           # relógio do estado atual (descida, espera, voo)
var _watch_clock := 0.0
var _last_announced := -1
var _departure := Vector3.UP
var _arrival := Vector3.UP


func _ready() -> void:
	add_to_group("home_base")
	_civilization = get_node_or_null("Civilization") as Civilization
	if _civilization == null:
		push_error("[HomeTerritory] %s precisa de um filho Civilization." % name)
		set_process(false)
		return
	EventBus.civilization_eliminated.connect(_on_eliminated)
	set_process(false)
	var planet := Services.planet
	if not planet.surface_ready:
		await planet.surface_became_ready
	_arrival = (global_position - planet.center).normalized()
	_place(_arrival, opening_altitude)
	_set_dome_visible(false)   # o domo só surge no GO (pouso concluído)
	set_process(true)


## Para testes e ferramentas: pula a cerimônia de abertura e a espera de pouso (o voo de realocação continua).
func skip_ceremony() -> void:
	opening_seconds = 0.0
	landed_wait_seconds = 0.0


func _exit_tree() -> void:
	if _civilization != null:
		Services.unregister_home_base(_civilization.id)


func _process(delta: float) -> void:
	var planet := Services.planet
	match state:
		State.OPENING_DESCENT:
			_clock += delta
			var progress := _progress(opening_seconds)
			_place(_arrival, opening_altitude * (1.0 - smoothstep(0.0, 1.0, progress)))
			_announce_if_near(opening_seconds - _clock)
			if progress >= 1.0:
				_land(planet)
		State.GROUNDED:
			_watch_for_takeover(delta)
		State.COUNTDOWN:
			_clock += delta
			if _clock >= relocation_delay_seconds:
				_begin_flight(planet)
		State.FLYING:
			_clock += delta
			var progress := _progress(flight_seconds)
			var direction := _departure.slerp(_arrival, smoothstep(0.0, 1.0, progress))
			_place(direction, sin(progress * PI) * flight_altitude)   # arco: altitude zero nas pontas
			_announce_if_near(flight_seconds - _clock)
			if progress >= 1.0:
				_land(planet)
		State.LANDED:
			_clock += delta
			var remaining := landed_wait_seconds - _clock
			_announce(remaining)
			if remaining <= 0.0:
				state = State.GROUNDED   # GO!: o domo de energia se materializa
				_watch_clock = 0.0
				_set_dome_visible(true)
				EventBus.base_relocated.emit(_civilization.id, global_position)
				print("[World] Civilização %d spawnou junto à nave (DD-100)." % _civilization.id)


func _progress(duration: float) -> float:
	return clampf(_clock / duration, 0.0, 1.0) if duration > 0.0 else 1.0


# Assenta a base a `altitude` sobre a superfície REAL (vales e morros), em pé.
func _place(direction: Vector3, altitude: float) -> void:
	var planet := Services.planet
	global_position = planet.center + direction * (planet.get_surface_radius(direction) + altitude)
	var forward := (-global_transform.basis.z).slide(direction)
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD.slide(direction)
	if forward.length_squared() < 0.001:
		forward = Vector3.RIGHT.slide(direction)
	global_transform.basis = Basis.looking_at(forward.normalized(), direction, true)


func _land(planet: Planet) -> void:
	var up := (global_position - planet.center).normalized()
	_place(up, 0.0)
	var cap_angle := asin(clampf(dome_radius / planet.radius, 0.0, 1.0))
	Services.territory.claim_cap(_civilization.id, up, cap_angle)
	Services.register_home_base(_civilization.id, global_position, dome_radius)
	_clock = 0.0
	_last_announced = -1
	state = State.LANDED
	print("[World] Nave da civilização %d pousou; campo se restabelecendo (DD-100)." % _civilization.id)


func _watch_for_takeover(delta: float) -> void:
	_watch_clock += delta
	if _watch_clock < OWNERSHIP_CHECK_INTERVAL:
		return
	_watch_clock = 0.0
	var territory := Services.territory
	if territory.is_owned_by(_civilization.id, global_position):
		return
	# DD-100: quem tomou a base herda o império inteiro; o derrotado embarca na hora.
	var conqueror: int = territory.get_owner_at(global_position)
	if conqueror != 0:
		territory.convert_all_cells_of(_civilization.id, conqueror)
		print("[World] Civilização %d tomou a base e HERDOU o império da civilização %d!" % [
				conqueror, _civilization.id])
	_set_dome_visible(false)   # o campo de força caiu
	EventBus.base_fallen.emit(_civilization.id, conqueror)
	if ruined:
		# DD-122: ruína conquistada não decola: o dono está morto. Nave e domo somem, o império tem novo dono.
		Services.unregister_home_base(_civilization.id)
		visible = false
		set_process(false)
		print("[World] Ruína da civilização %d foi conquistada (DD-122)." % _civilization.id)
		return
	_clock = 0.0
	state = State.COUNTDOWN
	print("[World] Nave da civilização %d decola em %.1f s (DD-100)." % [_civilization.id, relocation_delay_seconds])


func _begin_flight(planet: Planet) -> void:
	_departure = (global_position - planet.center).normalized()
	_arrival = (_pick_landing_position() - planet.center).normalized()
	_clock = 0.0
	_last_announced = -1
	state = State.FLYING


# Ponto livre sorteado pelo mapa, fora da faixa dos polos (volta com o último sorteio se não achar).
func _pick_landing_position() -> Vector3:
	var planet := Services.planet
	var pick := Vector3.ZERO
	for attempt in 32:
		pick = Services.territory.get_random_unowned_position()
		if absf((pick - planet.center).normalized().y) <= MAX_POLE_SIN:
			break
	return pick


func _announce_if_near(seconds_remaining: float) -> void:
	if seconds_remaining <= COUNTDOWN_LEAD_SECONDS:
		_announce(seconds_remaining + landed_wait_seconds)


func _announce(seconds_remaining: float) -> void:
	var whole := maxi(0, ceili(seconds_remaining))
	if whole != _last_announced:
		_last_announced = whole
		EventBus.respawn_countdown.emit(_civilization.id, whole)


func _set_dome_visible(show_it: bool) -> void:
	var dome := get_node_or_null("Dome") as Node3D
	if dome != null:
		dome.visible = show_it


func _on_eliminated(eliminated_id: int) -> void:
	if eliminated_id == _civilization.id:
		ruined = true
