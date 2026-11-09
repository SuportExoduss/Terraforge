extends SceneTree
## PLAYTEST: joga uma partida inteira (600 s) como a civilização 1, tentando dominar o máximo do planeta, contra 5 bots,
## e anota tudo que parece bug no log (linhas "BUG?", "OBS"). Não é um teste de passa/falha: é um relatório.
## Uso: godot_console --headless --quiet --path . --fixed-fps 60 -s res://tools/playtest_match.gd   (o log vai para PLAYTEST_LOG)   (900 s de timeout; 60 quadros = 1 s de jogo)
## Variáveis: PLAYTEST_SECONDS (duração da partida, padrão 600), PLAYTEST_BOTS (padrão 5).

const SNAP_EVERY := 15.0          # segundos de jogo entre fotos do estado
const NEAR_TRAIL := 1.0           # distância em que "encostou" no rastro (o corte vale em 1,5)
const SELF_SKIP := 12             # os últimos pontos do próprio rastro não contam como "encostar em si"

var _match: Node
var _bus: Node
var _services: Node
var _t := 0.0                     # segundos de jogo desde o início do script
var _go_t := -1.0
var _end_t := -1.0
var _wall_start := 0
var _file: FileAccess   # o log vai para ARQUIVO: print() no console do Windows custa 10-30 ms por linha e falsificava os picos de quadro
var _last_frame_usec := 0
var _frame_ms: Array[float] = []
var _worst: Array = []            # [ms, t, contexto]
var _next_snap := SNAP_EVERY
var _last_pos := {}               # id -> posição de 5 s atrás
var _last_move_check := 0.0
var _stuck_flagged := {}
var _loops := {}                  # id -> quantidade de circuitos fechados
var _loop_t := {}                 # id -> instante do último circuito (para ligar à conquista)
var _empty_loops := 0
var _self_touch := {}             # id -> quantas vezes encostou no próprio rastro (e nada aconteceu)
var _self_touch_clock := 0.0
var _cross_clock := 0.0
var _cross_seen := {}             # "a>b" -> instante do último toque (para o relógio de espera)
var _cuts := {}                   # "vítima>atacante" -> instante do corte
var _cross_missed := 0
var _cross_cut := 0
var _cross_mutual := 0
var _flags := {}                  # texto -> contagem (anomalias que se repetem não poluem o log)
var _state_log: Array = []
var _prev_dom := {}
var _peak_dom := {}
var _first_blood := false
var _max_claim := 0
var _claims := 0
var _claim_cells := 0
var _owned_sum_max := 0.0
var _ended := false
var _results_seen := false


func _initialize() -> void:
	var log_path := OS.get_environment("PLAYTEST_LOG") if OS.get_environment("PLAYTEST_LOG") != "" else "D:/Terraforge_Godot/.playtest_current.log"
	_file = FileAccess.open(log_path, FileAccess.WRITE)
	var seconds := float(OS.get_environment("PLAYTEST_SECONDS")) if OS.get_environment("PLAYTEST_SECONDS") != "" else 600.0
	var bots := int(OS.get_environment("PLAYTEST_BOTS")) if OS.get_environment("PLAYTEST_BOTS") != "" else 5
	load("res://scripts/core/profile.gd").path = "user://profile_playtest.json"
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").bot_count = bots
	_match.get_node("MatchTimer").duration_seconds = seconds
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_services = root.get_node("Services")
	_wall_start = Time.get_ticks_msec()
	_hook()
	_log("OBS", "playtest: %d bots, partida de %d s, 60 quadros por segundo de jogo" % [bots, int(seconds)])
	await process_frame
	_take_the_wheel()


# --- o jogador: um bot AGRESSIVO de conquista (saídas longas, mais tempo exposto, caça rastros perto)
func _take_the_wheel() -> void:
	var runner := _runner(1)
	var brain: Node = load("res://scripts/ai/bot_steering.gd").new()
	brain.min_sortie_distance = 26.0
	brain.max_sortie_distance = 60.0
	brain.max_exposure_seconds = 20.0
	brain.hunt_range = 22.0
	runner.use_steering(brain)


func _runner(id: int) -> Node:
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == id:
			return r
	return null


func _ids() -> Array:
	var ids: Array = []
	for r in get_nodes_in_group("runners"):
		ids.append(r.get_node("Civilization").id)
	ids.sort()
	return ids


func _say(a: Variant, b: Variant = "") -> void:
	_file.store_line(str(a) + str(b))
	_file.flush()


func _log(tag: String, msg: String) -> void:
	_say("[t=%6.1f] %-5s %s" % [_t, tag, msg])


func _flag_once(key: String, msg: String) -> void:
	_flags[key] = _flags.get(key, 0) + 1
	if _flags[key] == 1:
		_log("BUG?", msg)


# --- sinais do jogo
func _hook() -> void:
	_bus.match_started.connect(func() -> void:
		_go_t = _t
		_log("EVT", "GO! (a abertura levou %.1f s)" % _t))
	_bus.match_ended.connect(func() -> void:
		_end_t = _t
		_ended = true
		_log("EVT", "FIM DA PARTIDA"))
	_bus.match_state_changed.connect(func(s: int) -> void:
		_state_log.append(s)
		_log("EVT", "estado -> %d" % s))
	_bus.territory_loop_closed.connect(func(id: int, points: PackedVector3Array) -> void:
		_loops[id] = _loops.get(id, 0) + 1
		_loop_t[id] = _t
		if id == 1:
			_log("EVT", "VOCÊ fechou circuito com %d pontos" % points.size()))
	_bus.territory_cells_claimed.connect(func(id: int, cells: PackedVector3Array, _sp: float) -> void:
		_claims += 1
		_claim_cells += cells.size()
		_max_claim = maxi(_max_claim, cells.size())
		if id == 1 and cells.size() > 400:
			_log("EVT", "VOCÊ anexou %d células de uma vez" % cells.size())
		if _loop_t.has(id) and _t - _loop_t[id] < 2.0 and cells.size() < 8:
			_empty_loops += 1
			_flag_once("circuito_vazio_%d" % id, "circuito de %d fechou mas só anexou %d células (cerca sem área)" % [id, cells.size()]))
	_bus.territory_cells_converted.connect(func(id: int, frac: float) -> void:
		if id == 1:
			_log("EVT", "VOCÊ converteu %.1f%% do planeta de rivais" % (frac * 100.0)))
	_bus.trail_cut.connect(func(victim: int, attacker: int) -> void:
		_cuts["%d>%d" % [victim, attacker]] = _t
		_log("EVT", "corte: rastro de %d cortado por %d" % [victim, attacker]))
	_bus.trail_anchor_lost.connect(func(id: int) -> void: _log("EVT", "recall: civ %d perdeu a retaguarda" % id))
	_bus.base_fallen.connect(func(id: int, by: int) -> void: _log("EVT", "BASE de %d caiu para %d" % [id, by]))
	_bus.base_relocated.connect(func(id: int, _p: Vector3) -> void: _log("EVT", "nave de %d realocada" % id))
	_bus.civilization_eliminated.connect(func(id: int) -> void: _log("EVT", "ELIMINADA: civ %d" % id))
	_bus.civilization_killed.connect(func(v: int, k: int) -> void: _log("EVT", "kill: %d matou %d" % [k, v]))
	_bus.bonus_activated.connect(func(id: int, kind: String, s: float) -> void:
		if id == 1:
			_log("EVT", "bônus seu: %s %.0f s" % [kind, s]))
	_bus.global_event_warning.connect(func(n: String, s: int) -> void:
		if s == 5 or s == 10:
			_log("EVT", "aviso de evento: %s em %d s" % [n, s]))
	_bus.global_event_active_changed.connect(func(a: bool) -> void: _log("EVT", "evento global ativo=%s" % a))
	_bus.health_changed.connect(func(id: int, p: int, m: int) -> void:
		if id == 1:
			_log("EVT", "sua vida %d/%d" % [p, m]))
	_bus.respawn_countdown.connect(func(id: int, s: int) -> void:
		if id == 1 and s <= 5:
			_log("EVT", "respawn de VOCÊ em %d" % s))


# --- laço principal
func _process(delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last_frame_usec != 0:
		var ms := (now - _last_frame_usec) / 1000.0
		_frame_ms.append(ms)
		if ms > 60.0:
			_worst.append([ms, _t, "claims=%d painter_pend=%d process=%.0f physics=%.0f ms" % [_claims, _pending(),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]])
	_last_frame_usec = now
	_t += delta

	if _go_t >= 0.0 and not _ended:
		_watch(delta)
	if _t >= _next_snap:
		_next_snap += SNAP_EVERY
		_snapshot()
	if _ended and not _results_seen and _services.flow != null and _services.flow.state >= 8:
		_results_seen = true
		_finish_screen()
		_report()
		quit(0)
	if _t > 1100.0:
		_log("BUG?", "tempo esgotado antes da tela de resultados (estado %s)" % str(_services.flow.state if _services.flow != null else "?"))
		_report()
		quit(1)
	return false


func _pending() -> int:
	var planet: Node = _services.planet
	return planet.painter.pending_cells() if planet != null and planet.painter != null else -1


# Observações a cada quadro: encostar no próprio rastro / no rastro alheio, corredor parado, mundo fora de faixa.
func _watch(delta: float) -> void:
	var territory: Object = _services.territory
	_self_touch_clock += delta
	_cross_clock += delta
	if _self_touch_clock >= 0.1:
		_self_touch_clock = 0.0
		for trail in _services.trails:
			var pts: Array = trail.points
			if pts.size() <= SELF_SKIP + 2:
				continue
			var me: Vector3 = trail.get_parent().global_position
			for i in range(0, pts.size() - SELF_SKIP):
				if (pts[i] as Vector3).distance_to(me) < NEAR_TRAIL:
					_self_touch[trail.owner_id] = _self_touch.get(trail.owner_id, 0) + 1
					if _self_touch[trail.owner_id] == 1 or (_self_touch[trail.owner_id] % 25 == 0):
						_log("BUG?", "civ %d ENCOSTOU no PRÓPRIO rastro (ponto %d de %d) e nada fechou [x%d]" % [trail.owner_id, i, pts.size(), _self_touch[trail.owner_id]])
					break
	if _cross_clock >= 0.1:
		_cross_clock = 0.0
		for victim_trail in _services.trails:
			var vp: Array = victim_trail.points
			if vp.size() < 5:
				continue
			for other in _services.trails:
				if other == victim_trail:
					continue
				var who: Node3D = other.get_parent()
				if not who.is_active_in_field():
					continue
				for i in range(0, vp.size()):
					if (vp[i] as Vector3).distance_to(who.global_position) < NEAR_TRAIL:
						var key := "%d>%d" % [victim_trail.owner_id, other.owner_id]
						if _cross_seen.get(key, -9.0) < _t - 1.0:
							_cross_seen[key] = _t
							_check_cut_later(key, _t)
						break


# Encostou no rastro alheio: um corte tem que ter saído em até 1 s.
func _check_cut_later(key: String, at: float) -> void:
	await create_timer(1.0).timeout
	if _cuts.get(key, -9.0) >= at - 0.2:
		_cross_cut += 1
	elif _cut_near(int(key.get_slice(">", 1)), at):
		_cross_mutual += 1   # toque frente a frente: quem foi cortado primeiro é devolvido ao campo e não corta de volta (não é bug)
	else:
		_cross_missed += 1
		_flag_once("corte_perdido", "rastro de %s foi tocado (<%.1f) por outro corredor e NÃO cortou em 1 s [x%d]" % [key.replace(">", " por civ "), NEAR_TRAIL, _cross_missed])


# O corredor `id` teve o próprio rastro cortado em volta de `at`?
func _cut_near(id: int, at: float) -> bool:
	for key in _cuts:
		if (key as String).begins_with("%d>" % id) and absf(_cuts[key] - at) <= 0.5:
			return true
	return false


func _snapshot() -> void:
	var t: Object = _services.territory
	var parts: PackedStringArray = []
	var sum := 0.0
	for id in _ids():
		var r := _runner(id)
		var h: Node = r.get_node("Health")
		var f: float = t.owned_fraction(id)
		sum += f
		_peak_dom[id] = maxf(_peak_dom.get(id, 0.0), f)
		var dd: float = f - _prev_dom.get(id, 0.0)
		_prev_dom[id] = f
		var trail_pts := 0
		for tr in _services.trails:
			if tr.owner_id == id:
				trail_pts = tr.points.size()
		parts.append("%d:%4.1f%%(%+.1f) hp%d%s rastro%d" % [id, f * 100.0, dd * 100.0, h.points, "" if not r._eliminated else "X", trail_pts])
	_owned_sum_max = maxf(_owned_sum_max, sum)
	if sum > 1.0001:
		_flag_once("soma_maior_1", "soma das posses = %.3f > 1" % sum)
	_log("SNAP", " | ".join(parts) + "  (livre %.1f%%)" % ((1.0 - sum) * 100.0))
	var avg := 0.0
	var mx := 0.0
	for m in _frame_ms:
		avg += m
		mx = maxf(mx, m)
	avg /= maxf(1.0, _frame_ms.size())
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 10 else 0.0
	_log("PERF", "quadro médio %.1f ms, p99 %.1f ms, máx %.1f ms | nós %d, órfãos %d, objetos %d, mem %.0f MB | pintura pendente %d" % [
			avg, p99, mx, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT), OS.get_static_memory_usage() / 1048576.0, _pending()])
	_frame_ms.clear()
	# parado? (5 s sem se mexer 1 unidade enquanto ativo no campo)
	for id in _ids():
		var r := _runner(id)
		if r.is_active_in_field():
			var last: Variant = _last_pos.get(id)
			if last != null and (last as Vector3).distance_to(r.global_position) < 1.0:
				_flag_once("parado_%d" % id, "civ %d parado ~%d s no campo em %s" % [id, int(SNAP_EVERY), str(r.global_position)])
			_last_pos[id] = r.global_position
			var rad: float = (r.global_position - _services.planet.center).length()
			if rad < 90.0 or rad > 115.0 or is_nan(rad):
				_flag_once("fora_do_chao_%d" % id, "civ %d fora da faixa do chão: raio %.1f" % [id, rad])
		else:
			_last_pos.erase(id)


func _finish_screen() -> void:
	var stats: Node = _services.stats
	_log("EVT", "RESULTADOS: ranking %s" % str(stats.ranking()))
	for id in _ids():
		_log("EVT", "civ %d: domínio %.1f%% pico %.1f%% | circuitos %s cortes %s kills %s tomado %.1f%% %s" % [
				id, stats.dominance(id) * 100.0, stats.peak(id) * 100.0, str(stats.get_stat(id, "loops")), str(stats.get_stat(id, "cuts")),
				str(stats.get_stat(id, "kills")), stats.get_stat(id, "converted") * 100.0, "ELIMINADA" if stats.is_eliminated(id) else ""])
	var panel: Node = _match.get_node_or_null("Results")
	if panel != null:
		_log("EVT", "painel visível=%s" % str(panel._panel.visible))
		_log("EVT", "painel: " + panel._text.text.replace("\n", " / "))
		_log("EVT", "stats: " + panel._stats.text.replace("\n", " / "))
		_log("EVT", "recompensas: " + panel._rewards.text.replace("\n", " / "))
	else:
		_flag_once("sem_painel", "não achei o nó ResultsPanel")


func _report() -> void:
	var wall := (Time.get_ticks_msec() - _wall_start) / 1000.0
	_say("")
	_say("======== RESUMO DO PLAYTEST ========")
	_say("tempo de parede %.0f s para %.0f s de jogo (%.1fx)" % [wall, _t, _t / maxf(wall, 0.001)])
	_say("estados: ", _state_log)
	_say("circuitos fechados por civ: ", _loops)
	_say("anexos: %d (células %d, maior %d); circuitos vazios: %d" % [_claims, _claim_cells, _max_claim, _empty_loops])
	_say("encostou no PRÓPRIO rastro sem fechar (vezes, a 10 Hz): ", _self_touch)
	_say("encostou em rastro ALHEIO: cortou %d, toque mútuo %d, NÃO cortou %d" % [_cross_cut, _cross_mutual, _cross_missed])
	_say("pico de domínio por civ: ", _peak_dom)
	_worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	_say("piores quadros (>60 ms): %d" % _worst.size())
	for i in mini(8, _worst.size()):
		_say("  %.0f ms em t=%.1f (%s)" % [_worst[i][0], _worst[i][1], _worst[i][2]])
	_say("anomalias:", _flags)
