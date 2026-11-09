extends SceneTree
## Teste de fumaça do Passo 39 (Cap.03 P01 ABERTURA, DD-006): o menu abre com o planeta vivo ao fundo — planeta e nuvens
## girando (as nuvens mais rápido), atmosfera, estrelas, meteoros que cruzam o fundo e somem, aurora que acende e apaga —
## e o fundo não rouba o mouse dos botões. Uso: godot_console --headless --path . -s res://tools/smoke_backdrop.gd

var _time := 0.0


func _initialize() -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _run() -> void:
	await process_frame
	var menu := current_scene
	var back: Node = menu.get_node_or_null("Backdrop")
	if not _check(back != null and back.mouse_filter == Control.MOUSE_FILTER_IGNORE, "o menu tem o fundo vivo e ele deixa o mouse passar"): return
	if not _check(back.get_index() < menu.get_node("Box").get_index() and back.get_index() > 0, "o planeta fica atrás dos botões e à frente do fundo liso"): return
	if not _check(back.get_node("SubViewport/Stage").get_child_count() >= 5 and back.camera != null, "cena 3D montada (luz, planeta, nuvens, atmosfera, estrelas, câmera)"): return
	if not _check(back.spinner.get_child_count() > 0 and not back.spinner.find_children("*", "MeshInstance3D", true, false).is_empty(), "o modelo do planeta está no mundo"): return
	if not _check(back.get_node("SubViewport/Stage/Stars") != null and back.atmosphere != null and back.aurora != null, "estrelas, atmosfera e aurora existem"): return

	# Gira: planeta devagar, nuvens mais rápido
	var planet_before: float = back.spinner.rotation.y
	var clouds_before: float = back.clouds.rotation.y
	back._process(2.0)
	var planet_turn: float = back.spinner.rotation.y - planet_before
	var clouds_turn: float = back.clouds.rotation.y - clouds_before
	if not _check(planet_turn > 0.05 and clouds_turn > planet_turn * 1.2, "planeta gira e as nuvens giram mais rápido (%.3f x %.3f)" % [planet_turn, clouds_turn]): return
	back.running = false
	var frozen: float = back.spinner.rotation.y
	back._process(5.0)
	if not _check(back.spinner.rotation.y == frozen, "congelado quando running = falso"): return
	back.running = true

	# Meteoro: nasce, cruza o fundo e some
	var count_before: int = back.meteors_spawned
	back.spawn_meteor()
	var streak: Node3D = back.get_node("SubViewport/Stage/Meteor")
	if not _check(back.meteors_spawned == count_before + 1 and streak != null, "um meteoro nasce no fundo"): return
	var start: Vector3 = streak.position
	for i in 20:
		await process_frame
	if not _check(is_instance_valid(streak) and streak.position.distance_to(start) > 0.1, "o meteoro anda"): return
	await create_timer(PlanetBackdrop.METEOR_LIFE + 0.3).timeout
	if not _check(not is_instance_valid(streak) or streak.is_queued_for_deletion(), "o meteoro some no fim do caminho"): return

	# Aurora: apagada → acende → apaga
	if not _check(not back.aurora.visible and back.aurora_strength() == 0.0, "aurora apagada no começo"): return
	back.show_aurora()
	back._process(PlanetBackdrop.AURORA_SECONDS * 0.5)
	if not _check(back.aurora.visible and back.aurora_strength() > 0.5, "aurora acesa no meio do tempo"): return
	back._process(PlanetBackdrop.AURORA_SECONDS * 0.6)
	if not _check(not back.aurora.visible and back.auroras_shown >= 1, "aurora apaga sozinha"): return

	# Sorteio automático: com o relógio vencido, o processo dispara meteoros e aurora sem ninguém pedir
	var shown: int = back.auroras_shown
	var spawned: int = back.meteors_spawned
	for i in 40:
		back._process(1.0)
	if not _check(back.meteors_spawned > spawned + 2 and back.auroras_shown > shown, "meteoros e auroras ocasionais sozinhos"): return
	print("OK")
	quit(0)
