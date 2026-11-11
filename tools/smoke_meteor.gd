extends SceneTree
## Teste de fumaça do 6e (meteoro, DD-106/107/108): (1) o dano em anéis do Health — fora 0, anel externo 1,
## médio 2, interno 4; (2) o ciclo AVISO (contagem 2,1,0 + sombra) → IMPACTO (rocha cai; anéis 6/12/20 com
## dano 4/2/1) → CICATRIZ (cratera que some) → novo ciclo; (3) na janela de paz final nada cai mais.
## Tempos encurtados por exportação. Uso: godot_console --headless --path . -s res://tools/smoke_meteor.gd

var _match: Node
var _bus: Node
var _meteors: Node3D
var _time := 0.0
var _warnings: Array = []
var _strikes: Array = []


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_meteors = _match.get_node("Meteors")
	_meteors.min_seconds_between = 1.0
	_meteors.max_seconds_between = 1.0
	_meteors.quiet_after_start_seconds = 0.5
	_meteors.warning_seconds = 2.0
	_meteors.rock_fall_seconds = 1.0
	_meteors.scar_seconds = 2.0
	load("res://scripts/world/global_event.gd").gate_gap_seconds = 0.2   # DD-128: folga curta, o teste repete ciclos
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_bus.global_event_warning.connect(func(n, s): _warnings.append([n, s]))
	_bus.radial_damage.connect(func(c, ir, id, back, mr, md, orad, od): _strikes.append([c, ir, id, back, mr, md, orad, od]))
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


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	await _bus.match_started
	await process_frame
	await process_frame
	var planet: Node = root.get_node("Services").planet
	var runner: Node3D = _match.get_node("Main/Runner")
	var health: Node = _match.get_node("Main/Runner/Health")   # sem "Health": a classe usa autoload

	# 1. Dano em anéis (antes do primeiro meteoro, que só vem 1 s depois do GO)
	_strikes.clear()
	var side := runner.global_basis.x
	health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	_bus.radial_damage.emit(runner.global_position + side * 30.0, 6.0, 4, true, 12.0, 2, 20.0, 1)
	if not _check(health.points == 16, "fora do anel externo não deveria ferir (%d)" % health.points): return
	_bus.radial_damage.emit(runner.global_position + side * 15.0, 6.0, 4, true, 12.0, 2, 20.0, 1)
	if not _check(health.points == 15, "anel externo = -1 (%d)" % health.points): return
	_bus.radial_damage.emit(runner.global_position + side * 9.0, 6.0, 4, true, 12.0, 2, 20.0, 1)
	if not _check(health.points == 13, "anel médio = -2 (%d)" % health.points): return
	_bus.radial_damage.emit(runner.global_position, 6.0, 4, true, 12.0, 2, 20.0, 1)
	if not _check(health.points == 9, "anel interno = -4 (%d)" % health.points): return
	_strikes.clear()
	_warnings.clear()

	# 2. Aviso: contagem + sombra crescendo
	var shadow: Node3D = _meteors.get_node("Shadow")
	var rock: Node3D = _meteors.get_node("RockAnchor/Rock")
	var scar: Node3D = _meteors.get_node("Scar")
	await _bus.global_event_warning
	await process_frame
	if not _check(shadow.visible and not scar.visible and not rock.visible, "no aviso só a sombra aparece"): return
	var small: float = shadow.scale.x
	await _wait(0.6)
	if not _check(shadow.scale.x > small + 0.5, "a sombra deveria crescer (%.2f → %.2f)" % [small, shadow.scale.x]): return
	await _wait(0.9)   # ~1,5 s de aviso: faltam < 1 s → a rocha despenca
	if not _check(rock.visible, "a rocha deveria estar caindo"): return
	var rock_box := ModelUtils.local_aabb(rock)
	var rock_size := maxf(rock_box.size.x, maxf(rock_box.size.y, rock_box.size.z)) * rock.scale.x
	if not _check(absf(rock_size - 8.0) < 0.5, "rocha com ~8 u de diâmetro (%.2f)" % rock_size): return
	# Posição/direção: o CENTRO visual da rocha fica na vertical do ponto de impacto (não torto, não deslocado).
	if not _check(rock_box.get_center().length() < 0.01, "pivô no centro do modelo (%s)" % rock_box.get_center()): return
	var fall_dir: Vector3 = (rock.global_position - planet.center).normalized()
	var line_error: float = rad_to_deg(fall_dir.angle_to(_meteors._impact_direction))
	if not _check(line_error < 0.1, "rocha fora da linha do impacto (%.3f°)" % line_error): return

	# 3. Impacto
	await _bus.radial_damage
	await process_frame
	if not _check(_strikes.size() == 1, "um impacto por ciclo"): return
	var s: Array = _strikes[0]
	if not _check(s[1] == 6.0 and s[2] == 4 and s[3] == true and s[4] == 12.0 and s[5] == 2 and s[6] == 20.0 and s[7] == 1, "anéis do impacto: %s" % [s]): return
	var offset: Vector3 = (s[0] as Vector3) - planet.center
	if not _check(absf(offset.length() - planet.get_surface_radius(offset.normalized())) < 0.01, "impacto fora do chão"): return
	if not _check(_warnings.map(func(w): return w[1]) == [2, 1, 0], "contagem do aviso: %s" % [_warnings]): return
	if not _check(_warnings[0][0] == "METEORO CAINDO", "nome do evento"): return
	if not _check(not shadow.visible and not rock.visible and scar.visible, "depois do impacto: só a cratera"): return
	if not _check(scar.scale.x > 20.0, "cratera nasce com ~24 u (%.1f)" % scar.scale.x): return

	# 4. Cicatriz some e um novo ciclo começa
	await _wait(2.4)
	if not _check(not scar.visible, "a cratera deveria ter sumido"): return
	_warnings.clear()
	await _bus.global_event_warning
	if not _check(_warnings.size() == 1 and _warnings[0][1] == 2, "o ciclo deveria recomeçar com a contagem em 2: %s" % [_warnings]): return

	# 5. Janela de paz final: concluído este ciclo, nada mais cai
	_meteors.quiet_before_end_seconds = 100000.0
	await _bus.radial_damage
	_warnings.clear()
	await _wait(5.5)   # cicatriz (2 s) + espera (1 s) + folga
	if not _check(_warnings.is_empty(), "na paz final não deveria haver novo aviso: %s" % [_warnings]): return
	print("OK")
	quit(0)
