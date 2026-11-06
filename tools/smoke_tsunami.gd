extends SceneTree
## Teste de fumaça do Passo 12 (SYS-004 / DD-107, o TSUNAMI): (1) AVISO: contagem 2,1,0 + a onda aparece BAIXA;
## (2) EXECUÇÃO: a onda cruza o corredor parado → perde 3 pontos no total (espuma 1 → média 2 → centro 3, sem cobrar
## duas vezes) e é EMPURRADO; (3) CICATRIZ: poça no ponto final + bônus caindo no chão, a poça some e o ciclo
## recomeça; (4) uma onda que passa longe (outro círculo máximo) não fere ninguém; (5) na paz final nada vem.
## Tempos encurtados por exportação. Uso: godot_console --headless --path . -s res://tools/smoke_tsunami.gd

const SCAR := 4   # GlobalEvent.State.SCAR (sem citar a classe em scripts -s)
const ACTIVE := 3

var _match: Node
var _bus: Node
var _tsunami: Node3D
var _runner: Node3D
var _time := 0.0
var _warnings: Array = []
var _drops: Array = []
var _max_push := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_tsunami = _match.get_node("Tsunami")
	_tsunami.min_seconds_between = 1.0
	_tsunami.max_seconds_between = 1.0
	_tsunami.quiet_after_start_seconds = 0.5
	_tsunami.warning_seconds = 2.0
	_tsunami.scar_seconds = 2.0
	_tsunami.wave_speed = 60.0
	_tsunami.travel_degrees = 120.0
	root.add_child(_match)
	_runner = _match.get_node("Main/Runner")
	_runner.move_speed = 0.0   # parado: a onda passa exatamente por ele
	_bus = root.get_node("EventBus")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.bonus_drop_requested.connect(func(c, n): _drops.append([c, n]))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _tsunami.state == ACTIVE:
		_max_push = maxf(_max_push, _runner.push.length())
	if _time > 60.0:
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


# Onda que passa EXATAMENTE por cima do corredor (centro da onda sobre ele aos 90°).
func _aim_at_runner() -> void:
	var center: Vector3 = root.get_node("Services").planet.center
	var up := (_runner.global_position - center).normalized()
	var start := up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()
	_tsunami.plan(start, up)


# Onda num círculo máximo perpendicular ao corredor: passa a ~157 u dele, bem fora da largura.
func _aim_away_from_runner() -> void:
	var center: Vector3 = root.get_node("Services").planet.center
	var up := (_runner.global_position - center).normalized()
	var start := up.cross(Vector3.BACK if absf(up.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT).normalized()
	_tsunami.plan(start, up.cross(start))


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var planet: Node = root.get_node("Services").planet
	var health: Node = _match.get_node("Main/Runner/Health")
	var wave: Node3D = _tsunami.get_node("Wave8")
	var puddle: Node3D = _tsunami.get_node("Puddle")

	# 1. Aviso: contagem + onda baixa
	await _bus.global_event_warning
	_aim_at_runner()
	await process_frame
	if not _check(wave.visible and not puddle.visible, "no aviso só a onda aparece"): return
	if not _check(wave.scale.y < 1.5, "a onda começa baixa (%.2f)" % wave.scale.y): return
	await _wait(1.0)
	if not _check(wave.scale.y > 1.5, "a onda deveria se levantar (%.2f)" % wave.scale.y): return

	# 2. Execução: espuma 1 → média 2 → centro 3 (total 3) + empurrão forte
	while _tsunami.state != SCAR:
		await process_frame
	if not _check(health.points == 13, "o centro da onda tira 3 no total, sem cobrar em dobro (%d)" % health.points): return
	if not _check(_max_push > 20.0, "o centro empurra forte (%.1f u/s)" % _max_push): return
	if not _check(_warnings.map(func(w): return w[1]) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "TSUNAMI VINDO", "nome do evento"): return

	# 3. Cicatriz: poça no ponto final e bônus no chão
	if not _check(puddle.visible and not wave.visible, "depois da passagem: só a poça"): return
	if not _check(_drops.size() == 1, "um bônus por tsunami (%d)" % _drops.size()): return
	var at: Vector3 = (_drops[0][0] as Vector3) - planet.center
	if not _check(absf(at.length() - planet.get_surface_radius(at.normalized())) < 0.01, "bônus fora do chão"): return
	if not _check(_drops[0][1] >= 1 and _drops[0][1] <= 3, "bônus de 1 a 3 (%d)" % _drops[0][1]): return
	await _wait(2.4)
	if not _check(not puddle.visible, "a poça deveria ter secado"): return

	# 4. Novo ciclo: onda que passa longe não fere
	_warnings.clear()
	await _bus.global_event_warning
	_aim_away_from_runner()
	var before: int = health.points
	while _tsunami.state != SCAR:
		await process_frame
	if not _check(health.points == before, "onda distante não fere (%d → %d)" % [before, health.points]): return
	if not _check(_warnings.size() == 3 and _warnings[0][1] == 2, "o ciclo recomeça com a contagem em 2: %s" % [_warnings]): return

	# 5. Paz final
	_tsunami.quiet_before_end_seconds = 100000.0
	await _wait(2.4 + 1.0 + 3.0)   # cicatriz + espera + folga
	_warnings.clear()
	await _wait(4.0)
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
