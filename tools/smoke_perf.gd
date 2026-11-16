extends SceneTree
## Teste de fumaça do Passo 35 (otimização, OP-001..006 / DD-092..094): (1) o medidor calcula média/pior/p95/FPS e o anel
## guarda só os últimos quadros; (2) F3 liga/desliga o painel; (3) na partida o medidor colhe quadros de verdade e o
## quadro fica dentro do orçamento do DD-124; (4) o planeta tem um oclusor esférico MENOR que o terreno (o lado de trás
## não é desenhado, sem nunca esconder o que se vê) e a oclusão está ligada; (5) a partida não vaza memória: depois de
## liberar a partida, a contagem de nós volta ao que era.
## Uso: godot_console --headless --path . --fixed-fps 60 -s res://tools/smoke_perf.gd

var _bus: Node
var _failed := false


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _initialize() -> void:
	_run()


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _run() -> void:
	_bus = root.get_node("EventBus")

	# 1. Estatísticas
	var meter: Node = load("res://scripts/core/perf_meter.gd").new()
	meter.set_process(false)   # só os quadros que o teste injeta entram na conta
	root.add_child(meter)
	await process_frame        # _ready cria o painel
	_check(meter.average_ms() == 0.0 and meter.fps() == 0.0 and meter.sample_count() == 0, "medidor novo começa zerado")
	for i in 100:
		meter.record(10.0)
	_check(is_equal_approx(meter.average_ms(), 10.0) and is_equal_approx(meter.fps(), 100.0), "média de 100 quadros de 10 ms")
	_check(meter.within_budget() and is_equal_approx(meter.p95_ms(), 10.0), "quadros de 10 ms estão no orçamento")
	for i in 20:
		meter.record(60.0)   # engasgos: a média mal sobe, mas o p95 denuncia
	_check(is_equal_approx(meter.worst_ms(), 60.0), "pior quadro")
	_check(meter.p95_ms() >= 60.0 and not meter.within_budget(), "20 engasgos em 120 quadros estouram o orçamento (p95 %.1f)" % meter.p95_ms())
	for i in meter.WINDOW:
		meter.record(5.0)
	_check(meter.sample_count() == meter.WINDOW and is_equal_approx(meter.average_ms(), 5.0) and meter.worst_ms() == 5.0, "o anel guarda só os últimos %d quadros" % meter.WINDOW)
	_check(meter.report().contains("FPS") and meter.report().contains("nós"), "o relatório traz FPS e nós")

	# 2. Painel com F3
	var key := InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	_check(not meter.overlay_visible, "painel começa escondido")
	meter._unhandled_key_input(key)
	_check(meter.overlay_visible, "F3 deve mostrar o painel")
	meter._process(0.3)   # passou mais que o intervalo do painel: refaz o texto
	_check(meter._label.visible and meter._label.text.contains("FPS"), "o painel deve mostrar o relatório")
	meter._unhandled_key_input(key)
	_check(not meter.overlay_visible and not meter._label.visible, "F3 de novo esconde o painel")
	meter.free()

	# 1b. Resolução adaptativa (celular): lento abaixa um passo (piso 50%), folgado e calmo devolve (teto = a da qualidade)
	var gov = load("res://scripts/core/perf_meter.gd")
	_check(is_equal_approx(gov.next_scale(0.85, 0.85, 30.0, false), 0.80), "quadro lento (30 ms) abaixa a resolução um passo")
	_check(is_equal_approx(gov.next_scale(0.50, 0.85, 40.0, false), 0.50), "a resolução nunca passa do piso de 50%")
	_check(is_equal_approx(gov.next_scale(0.70, 0.85, 12.0, true), 0.75), "quadro folgado e calmo devolve um passo")
	_check(is_equal_approx(gov.next_scale(0.70, 0.85, 12.0, false), 0.70), "sem calma (caiu há pouco) não sobe")
	_check(is_equal_approx(gov.next_scale(0.85, 0.85, 12.0, true), 0.85), "a resolução nunca passa do teto da qualidade")
	_check(is_equal_approx(gov.next_scale(0.70, 0.85, 20.0, true), 0.70), "entre FAST e SLOW fica onde está")
	var governed: Node = gov.new()   # a fiação: um quadro lento de verdade derruba a resolução da janela; ao sair, a escolhida volta
	governed.governor_on = true
	governed.set_process(false)
	root.add_child(governed)
	await process_frame
	var scale_before := root.scaling_3d_scale
	governed._govern(2.5)
	_check(root.scaling_3d_scale < scale_before, "_govern abaixa a resolução 3D da janela (%.2f -> %.2f)" % [scale_before, root.scaling_3d_scale])
	governed.free()
	_check(is_equal_approx(root.scaling_3d_scale, scale_before), "ao sair, a resolução escolhida volta (%.2f)" % root.scaling_3d_scale)
	var settings = load("res://scripts/core/settings.gd")   # load(): `Settings` direto compilaria antes dos autoloads
	_check(settings.default_quality() == (1 if OS.has_feature("mobile") else settings.DEFAULTS["quality"]), "qualidade padrão: MÉDIA no celular, a do projeto no PC")

	# 3 e 4. Partida: medidor colhendo quadros, oclusor do planeta
	var before := _nodes()
	var match_scene: Node = load("res://scenes/match.tscn").instantiate()
	match_scene.get_node("MatchSetup").skip_ceremony = true
	match_scene.get_node("MatchSetup").bot_count = 0
	match_scene.get_node("Meteors").min_seconds_between = 100000.0
	match_scene.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(match_scene)
	await _bus.match_started
	for i in 90:
		await process_frame
	var perf: Node = match_scene.get_node_or_null("Perf")
	_check(perf != null, "a partida deve ter o medidor (nó Perf)")
	_check(perf.sample_count() >= 60, "o medidor deve colher quadros (%d)" % perf.sample_count())
	_check(perf.within_budget(), "partida fora do orçamento de quadro: %s" % perf.report())
	var planet: Node = match_scene.get_node("Main/Planet")
	var occluder := planet.get_node_or_null("Occluder") as OccluderInstance3D
	_check(occluder != null and occluder.occluder is SphereOccluder3D, "o planeta deve ter um oclusor esférico")
	var share: float = occluder.occluder.radius / planet.radius
	_check(share > 0.5 and share < 0.95, "o oclusor tem de ficar dentro do terreno (%.2f do raio)" % share)
	_check(absf(occluder.global_position.distance_to(planet.center)) < 0.01, "o oclusor fica no centro do planeta")
	_check(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false), "a oclusão de objetos deve estar ligada no projeto")

	# 5. Sem vazamento: liberar a partida devolve os nós
	match_scene.queue_free()
	for i in 10:
		await process_frame
	await create_timer(0.3).timeout
	var left := _nodes() - before
	_check(left <= 8, "a partida deixou %d nós vivos depois de liberada" % left)

	if not _failed:
		print("OK")
		quit(0)
