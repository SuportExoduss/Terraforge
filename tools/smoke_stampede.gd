extends SceneTree
## Teste de fumaça do Passo 77 (SYS-004 / DD-107, a MANADA): (1) aviso: faixa acesa no chão, touros escondidos, contagem
## 2-1-0, minimapa aponta o meio da faixa; (2) execução: 5 touros correm (andam, animação Trot); (3) no caminho: 3 pts +
## volta à base, uma pancada só; (4) ao lado da fila (6 u): ainda atropela; (5) longe (12 u): 0 pt; (6) cicatriz: pegadas
## + 2 a 3 cristais, tudo some depois; (7) paz final. Tempos encurtados por exportação.
## Uso: godot_console --headless --path . -s res://tools/smoke_stampede.gd

const ACTIVE := 3   # GlobalEvent.State (sem citar a classe em scripts -s)
const SCAR := 4

var _match: Node
var _bus: Node
var _herd: Node3D
var _runner: Node3D
var _health: Node
var _services: Node
var _antipode := Vector3.ZERO
var _base_pos := Vector3.ZERO
var _time := 0.0
var _warnings: Array = []
var _drops: Array = []
var _min_points := 16
var _moved := 0.0
var _trot := false
var _herd_seen := false


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Bonuses").free()   # cristais caem junto do corredor parado: Vida Extra/Escudo sorteado falsearia a vida
	for other in ["Meteors", "Tsunami", "Volcano", "Hurricane", "AcidRain", "Earthquake", "GiantWorm"]:
		_match.get_node(other).min_seconds_between = 100000.0
		_match.get_node(other).max_seconds_between = 100000.0
	_herd = _match.get_node("Stampede")
	_herd.min_seconds_between = 1.0
	_herd.max_seconds_between = 1.0
	_herd.quiet_after_start_seconds = 0.5
	_herd.warning_seconds = 1.5
	_herd.scar_seconds = 2.0
	_herd.run_seconds = 2.0
	load("res://scripts/world/global_event.gd").gate_gap_seconds = 0.2   # DD-128: folga curta, o teste repete ciclos
	root.add_child(_match)
	_runner = _match.get_node("Main/Runner")
	_runner.move_speed = 0.0   # parado: quem sofre é o corredor
	_health = _match.get_node("Main/Runner/Health")
	_bus = root.get_node("EventBus")
	_services = root.get_node("Services")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.bonus_drop_requested.connect(func(c, n): _drops.append([c, n]))
	_bus.health_changed.connect(func(_id, p, _m): _min_points = mini(_min_points, p))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _herd.state == ACTIVE:
		var lead: Node3D = _herd.get_node("Bull0")
		_herd_seen = _herd_seen or lead.visible
		var anim := lead.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_trot = _trot or (anim != null and anim.current_animation == "Trot" and anim.is_playing())
	if _time > 150.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _up() -> Vector3:
	return (_runner.global_position - _services.planet.center).normalized()


func _side(up: Vector3) -> Vector3:
	return up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()


# Faixa que passa `lateral` u ao lado do corredor, com a cabeça da manada chegando a ele no meio da corrida.
func _arm(lateral: float) -> void:
	var up := _up()
	var heading := _side(up)
	var radius: float = _services.planet.radius
	var center := up.rotated(heading, lateral / radius)   # girar em torno da tangente afasta o ponto de lado
	var half: float = _herd.speed * _herd.run_seconds * 0.5 / radius
	var axis := center.cross(heading).normalized()
	_herd.plan(center.rotated(axis, -half), heading.rotated(axis, -half))
	_drops.clear()
	_min_points = _health.points
	_trot = false
	_herd_seen = false


func _until_scar() -> void:
	while _herd.state != SCAR:
		await process_frame


# Um ciclo com a faixa `lateral` u ao lado; devolve a menor vida vista.
func _cycle(lateral: float) -> int:
	_health.heal(16)
	_runner.teleport_to(_antipode)
	await process_frame
	await _bus.global_event_warning
	_arm(lateral)
	await _until_scar()
	var lowest := _min_points
	await _wait(2.4)   # a cicatriz some
	return lowest


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var civ_id: int = _match.get_node("Main/Runner/Civilization").id
	_base_pos = _services.home_bases[civ_id]["position"]
	var center: Vector3 = _services.planet.center
	_antipode = center - (_base_pos - center)
	_runner.teleport_to(_antipode)
	await process_frame

	# 1. Aviso: faixa acesa, touros escondidos, contagem, minimapa
	await _bus.global_event_warning
	await process_frame
	if not _check(_herd.get_node("Lane0").visible and _herd.get_node("Lane13").visible, "no aviso a faixa está acesa"): return
	if not _check(not _herd.get_node("Bull0").visible and not _herd.get_node("Print0").visible, "no aviso os touros não aparecem"): return
	if not _check(not _herd.minimap_focus().is_empty(), "o minimapa mostra o meio da faixa"): return
	_health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	_arm(0.0)

	# 2. Execução: os touros correm de verdade
	while _herd.state != ACTIVE:
		await process_frame
	await _wait(0.3)
	var first: Vector3 = _herd.get_node("Bull0").global_position
	await _wait(0.4)
	_moved = _herd.get_node("Bull0").global_position.distance_to(first)
	if not _check(_moved > 6.0 and _moved < 11.0, "o líder corre ~22 u/s (andou %.1f em 0,4 s)" % _moved): return
	if not _check(_herd.get_node("Bull4").visible, "os 5 touros aparecem"): return
	await _until_scar()

	# 3. No caminho: 3 pts + volta à base, uma pancada só
	if not _check(_herd_seen and _trot, "o líder apareceu e anima Trot"): return
	if not _check(_min_points == 13, "atropelado: 3 pts (menor vida %d)" % _min_points): return
	if not _check(_runner.global_position.distance_to(_base_pos) < 8.0, "atropelado: volta ao campo de força"): return
	if not _check(_warnings.map(func(w): return w[1]).slice(0, 3) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "MANADA SE APROXIMANDO", "nome do evento"): return

	# 6. Cicatriz: pegadas, sem faixa nem touros, cristais
	if not _check(_herd.get_node("Print0").visible and _herd.get_node("Print19").visible, "cicatriz: pegadas"): return
	if not _check(not _herd.get_node("Lane0").visible and not _herd.get_node("Bull0").visible, "cicatriz: sem faixa nem touros"): return
	if not _check(_drops.size() == 1 and _drops[0][1] >= 2 and _drops[0][1] <= 3, "cristais (2 a 3): %s" % [_drops]): return
	await _wait(2.4)
	if not _check(not _herd.get_node("Print0").visible, "as pegadas deveriam ter sumido"): return

	# 4/5. Ao lado da fila ainda atropela (touro de ponta a 1 u); longe da faixa não
	var beside := await _cycle(6.0)
	if not _check(beside == 13, "6 u ao lado: atropela (menor vida %d)" % beside): return
	var far := await _cycle(12.0)
	if not _check(far == 16, "12 u ao lado: não atropela (menor vida %d)" % far): return
	if not _check(_runner.global_position.distance_to(_antipode) < 3.0, "quem escapou não vai à base"): return

	# 7. Paz final
	_herd.quiet_before_end_seconds = 100000.0
	await _wait(1.0 + 3.0)
	_warnings.clear()
	await _wait(4.0)
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
