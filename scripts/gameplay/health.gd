class_name Health
extends Node
## A vida oficial (DD-105): 16 pontos = 4 corações x 4 segmentos. Corte de rastro tira 2 pontos e
## devolve o corredor à base (R2); o campo de força regenera 1 ponto a cada 1,5 s (R3); zerar os 4
## corações ELIMINA a civilização (R1). Eventos, defensores e armadilhas usam take_damage(1/2/4).
## Nó filho de um PlanetRunner (precisa do irmão "Civilization").
## DD-123: perder a retaguarda NÃO tira vida; o próprio corredor volta andando (PlanetRunner).

const MAX_POINTS := 16
const RETURN_PROTECTION := 2.0   # SYS-003 RESPAWN: ao voltar ao campo o jogador fica 2 s sem perder pontos (anda e conquista normalmente)
const MAX_EXTRA_POINTS := 4   # SYS-005: o bônus Vida Extra acrescenta, no máximo, 1 coração (teto de balanceamento)

@export var cut_damage_points := 2
@export var seconds_per_regen_point := 1.5

var points := MAX_POINTS
var max_points := MAX_POINTS
var shield_left := 0.0   # SYS-005 Escudo Temporal: enquanto > 0, nenhum dano tira pontos (o corte do rastro acontece igual)

var _runner: PlanetRunner
var _civilization: Civilization
var _regen_clock := 0.0
var _eliminated := false


func _ready() -> void:
	_runner = get_parent() as PlanetRunner
	_civilization = get_parent().get_node_or_null("Civilization") as Civilization
	if _runner == null or _civilization == null:
		push_error("[Health] %s precisa estar sob um PlanetRunner com crachá Civilization." % name)
		set_process(false)
		return
	EventBus.trail_cut.connect(_on_trail_cut)
	EventBus.base_relocated.connect(_on_base_relocated)
	EventBus.radial_damage.connect(_on_radial_damage)
	_publish_points.call_deferred()   # os ouvintes (HUD) nascem depois; o 1º valor chega a eles


func _process(delta: float) -> void:
	shield_left = maxf(0.0, shield_left - delta)
	if _eliminated or points >= MAX_POINTS:
		return
	var base: Dictionary = Services.home_bases.get(_civilization.id, {})
	if base.is_empty() or _runner.global_position.distance_to(base["position"]) > base["radius"]:
		_regen_clock = 0.0
		return
	_regen_clock += delta
	if _regen_clock >= seconds_per_regen_point:
		_regen_clock -= seconds_per_regen_point
		heal(1)


## Dano de qualquer origem (corte, eventos, defensores).
func take_damage(amount: int, cause := "DANO") -> void:
	if _eliminated or shield_left > 0.0:
		return
	points = maxi(0, points - amount)
	EventBus.damage_taken.emit(_civilization.id, amount, cause)
	if points <= 0:
		eliminate()
	else:
		_publish_points()


## R1: fora da partida. Também usada pelo servidor quando quem caiu não volta a tempo (ignora o escudo).
func eliminate() -> void:
	if _eliminated:
		return
	points = 0
	_publish_points()
	_eliminated = true
	EventBus.civilization_eliminated.emit(_civilization.id)
	print("[Gameplay] Civilização %d foi ELIMINADA da partida!" % _civilization.id)


func heal(amount: int) -> void:
	if _eliminated:
		return
	points = mini(max_points, points + amount)
	_publish_points()


## Recuperação do servidor: valor ABSOLUTO (restaurar duas vezes não duplica vida nem escudo). Quem chama valida 0..teto.
func restore(saved_points: int, saved_shield: float) -> void:
	max_points = maxi(max_points, saved_points)
	points = saved_points
	shield_left = saved_shield
	if points <= 0:
		eliminate()
	else:
		_publish_points()


## SYS-005 Vida Extra: +1 coração cheio, até o teto. A regeneração do campo continua parando nos 16 normais.
func grant_extra_heart() -> void:
	if _eliminated:
		return
	max_points = mini(MAX_POINTS + MAX_EXTRA_POINTS, max_points + 4)
	points = mini(max_points, points + 4)
	_publish_points()


## SYS-005 Escudo Temporal.
func grant_shield(seconds: float) -> void:
	shield_left = maxf(shield_left, seconds)


func _on_trail_cut(victim_id: int, attacker_id: int) -> void:
	if victim_id != _civilization.id or _eliminated:
		return
	take_damage(cut_damage_points, "RASTRO CORTADO")
	if _eliminated:
		EventBus.civilization_killed.emit(victim_id, attacker_id)   # a apuração credita a eliminação a quem cortou
	else:
		return_to_force_field()


# DD-107: dano de eventos globais em anéis exclusivos; o anel interno também devolve a vítima ao campo.
func _on_radial_damage(center: Vector3, inner_radius: float, inner_damage: int, inner_returns_to_base: bool,
		mid_radius: float, mid_damage: int, outer_radius: float, outer_damage: int) -> void:
	if _eliminated:
		return
	var distance := _runner.global_position.distance_to(center)
	if distance <= inner_radius:
		take_damage(inner_damage, "IMPACTO")
		if not _eliminated and inner_returns_to_base:
			return_to_force_field()
	elif distance <= mid_radius:
		take_damage(mid_damage, "IMPACTO")
	elif distance <= outer_radius:
		take_damage(outer_damage, "IMPACTO")


# DD-100: perdeu a base = recomeço junto à nave, com a vida cheia.
func _on_base_relocated(owner_id: int, new_position: Vector3) -> void:
	if owner_id != _civilization.id or _eliminated:
		return
	_runner.teleport_to(new_position)
	shield_left = maxf(shield_left, RETURN_PROTECTION)
	points = max_points
	_publish_points()


## DD-107: devolve o corredor ao campo de força (anel interno dos eventos, 4ª bola do Vulcão...).
func return_to_force_field() -> void:
	var base: Dictionary = Services.home_bases.get(_civilization.id, {})
	if not base.is_empty():
		_runner.teleport_to(base["position"])
		shield_left = maxf(shield_left, RETURN_PROTECTION)


func _publish_points() -> void:
	EventBus.health_changed.emit(_civilization.id, points, max_points)
