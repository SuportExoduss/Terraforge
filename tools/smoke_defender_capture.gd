extends SceneTree
## Teste de fumaça do Passo 146 (DD-186): o defensor do derrotado passa para o conquistador e corre até a nave dele.
## (1) tomar menos de 2% não captura; (2) tomar 5% troca UM defensor da vítima (dono, anel na cor nova, sinal) e ele entra em transferência;
## (3) uma captura por vítima a cada 20 s; (4) o capturado corre rumo à nave do conquistador e, ao chegar, vira patrulha dentro do
## território novo; (5) o capturado é EXTRA: não entra na conta do equilíbrio do dono e a vítima repõe o dela; (6) no máximo 2 capturados
## por conquistador; (7) base conquistada leva os que sobraram; (8) conquistador eliminado perde os capturados.
## Uso: godot_console --headless --path . -s res://tools/smoke_defender_capture.gd

const RETURN := 4   # = DefenderSystem.State (a classe não é citada: no modo -s ela compilaria antes dos autoloads)
const REST := 5

var _match: Node
var _bus: Node
var _services: Node
var _defenders: Node
var _time := 0.0
var _captures: Array = []


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 2
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_services = root.get_node("Services")
	_bus.defender_captured.connect(func(conqueror: int, victim: int): _captures.append([conqueror, victim]))
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 60.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _of(id: int) -> Array:
	return _defenders._guards.filter(func(g): return g.owner_id == id)


func _captured_of(id: int) -> Array:
	return _defenders._guards.filter(func(g): return g.owner_id == id and g.captured)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Espera tempo de jogo (o quadro dura o que o computador levar; os defensores andam por segundo).
func _wait(seconds: float) -> void:
	var end := _time + seconds
	while _time < end:
		await process_frame


func _run() -> void:
	await _bus.match_started
	_defenders = _match.get_node("Defenders")
	for id in [1, 2, 3]:
		_match.get_node("Main/Runner" + ("" if id == 1 else str(id))).set_process(false)   # ninguém fecha circuito durante o teste
	while _of(1).is_empty() or _of(2).is_empty() or _of(3).is_empty():
		await process_frame
	await _frames(5)
	var victim_before := _of(2).size()
	var mine_before := _of(1).size()
	var mine_regular := _of(1).filter(func(g): return not g.captured).size()

	# 1. Tomar pouco (1%) não captura
	_bus.territory_taken.emit(1, 2, 0.01)
	await _frames(2)
	if not _check(_captures.is_empty() and _of(2).size() == victim_before and _of(1).size() == mine_before, "1 por cento do planeta não captura defensor"): return

	# 2. Tomar 5% captura UM
	_bus.territory_taken.emit(1, 2, 0.05)
	await _frames(2)
	if not _check(_captures == [[1, 2]], "sinal defender_captured(1, 2) (%s)" % [_captures]): return
	var taken: Array = _captured_of(1)
	if not _check(taken.size() == 1 and _of(1).size() == mine_before + 1, "o conquistador ganhou 1 defensor capturado (%d)" % taken.size()): return
	if not _check(_of(2).size() == victim_before - 1 or _of(2).size() == victim_before, "a vítima perdeu 1 (ou já repôs): %d de %d" % [_of(2).size(), victim_before]): return
	var guard = taken[0]
	var mark_color: Color = (guard.node.get_node("CivMark").mesh.material as StandardMaterial3D).albedo_color
	if not _check(mark_color == _defenders._mark_color(1) and mark_color != _defenders._mark_color(2), "o anel ficou na cor do novo dono"): return
	if not _check(guard.transferring and guard.state == RETURN, "o capturado entra em transferência (RETURN)"): return

	# 3. Uma captura por vítima a cada 20 s
	_bus.territory_taken.emit(1, 2, 0.05)
	await _frames(2)
	if not _check(_captured_of(1).size() == 1 and _captures.size() == 1, "segunda varredura em seguida não captura (recarga da vítima)"): return

	# 4. O capturado corre até a nave do novo dono e vira patrulha ali
	var home: Vector3 = _services.home_bases[1]["position"]
	var planet = _services.planet
	guard.position = planet.center - (home - planet.center)   # pior caso: do OUTRO lado do planeta (a corda até a nave degenera)
	var start: Vector3 = guard.position
	await _wait(1.0)
	var run: float = guard.position.distance_to(start)
	if not _check(guard.transferring and run > 3.0, "o capturado corre mesmo no lado oposto do planeta (andou %.1f)" % run): return
	if not _check(absf(guard.position.distance_to(planet.center) - planet.radius) < 8.0, "e continua na superfície (%.1f do centro)" % guard.position.distance_to(planet.center)): return
	var d1: float = guard.position.distance_to(home)
	if not _check(d1 > 150.0, "ainda está longe da nave (%.1f), a corrida segue" % d1): return
	guard.position = home
	await _frames(3)
	if not _check(not guard.transferring and guard.state == REST, "chegou: deixa de ser transferência e fica em repouso"): return
	await _wait(1.5)
	if not _check(_services.territory.is_owned_by(1, guard.position), "depois de chegar patrulha DENTRO do território do novo dono"): return

	# 5. Extra: o equilíbrio do dono ignora capturados, e a vítima repõe o dela
	await _wait(2.5)
	if not _check(_of(1).filter(func(g): return not g.captured).size() == mine_regular, "o capturado não conta no equilíbrio do dono"): return
	if not _check(_of(2).size() >= 1 and _of(2).size() == victim_before, "a vítima repôs o defensor dela (%d de %d)" % [_of(2).size(), victim_before]): return

	# 6. Teto de 2 capturados por conquistador
	_defenders._next_capture.clear()
	_bus.territory_taken.emit(1, 2, 0.05)
	await _frames(2)
	if not _check(_captured_of(1).size() == 2, "segundo capturado entra (%d)" % _captured_of(1).size()): return
	var third_before := _of(3).size()
	_defenders._next_capture.clear()
	_bus.territory_taken.emit(1, 3, 0.05)
	await _frames(2)
	if not _check(_captured_of(1).size() == 2 and _of(3).size() == third_before, "teto: com 2 capturados o terceiro não passa"): return

	# 7. Base conquistada leva os defensores que sobraram (até o teto do conquistador)
	var left := _of(3).size()
	_bus.base_fallen.emit(3, 2)
	await _frames(2)
	if not _check(_captured_of(2).size() == mini(left, 2) and _of(3).size() == left - mini(left, 2), "base de 3 conquistada por 2: %d capturados de %d" % [_captured_of(2).size(), left]): return
	_bus.base_fallen.emit(3, 0)   # sem conquistador (0): nada muda
	await _frames(2)
	if not _check(_captured_of(2).size() == mini(left, 2), "base caída sem conquistador não captura"): return

	# 7b. Fluxo real: o território anuncia quanto a vítima perdeu e o defensor troca de lado sem emitir nada na mão
	var taken_signals: Array = []
	_bus.territory_taken.connect(func(c: int, v: int, f: float): taken_signals.append([c, v, f]))
	var home2: Vector3 = _services.home_bases[2]["position"]
	var dir2: Vector3 = (home2 - _services.planet.center).normalized()
	_services.territory.claim_cap(2, dir2, 0.4)   # a civilização 2 cresce (~4% do planeta)...
	_defenders._next_capture.clear()
	taken_signals.clear()
	var before3 := _captured_of(3).size()
	_services.territory.claim_cap(3, dir2, 0.4)   # ...e a 3 toma tudo
	await _frames(3)
	var hit: Array = taken_signals.filter(func(t): return t[0] == 3 and t[1] == 2 and t[2] > 0.02)
	if not _check(not hit.is_empty(), "conquista real de 3 sobre 2 emite territory_taken com a fração perdida (%s)" % [taken_signals]): return
	if not _check(_captured_of(3).size() == before3 + 1, "conquista real: civilização 3 ganhou 1 defensor capturado (%d -> %d)" % [before3, _captured_of(3).size()]): return

	# 8. Conquistador eliminado perde todos os defensores, capturados inclusive
	_defenders._on_eliminated(1)
	await _frames(2)
	if not _check(_of(1).is_empty(), "civilização 1 eliminada: nenhum defensor dela sobra"): return

	print("OK: defensor do derrotado passa para o conquistador, corre até a nave dele, é extra, tem recarga e teto")
	quit(0)
