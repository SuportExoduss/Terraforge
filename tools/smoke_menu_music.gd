extends SceneTree
## Teste de fumaça do Passo 49 (música do menu, Cap.03 P01): o menu toca uma trilha suave (a base entra baixinho e sobe,
## a camada de pulso fica quieta); abrir uma tela faz entrar a camada de pulso, e ela continua depois de fechar a tela;
## clicar JOGAR abaixa a música junto com o mergulho.
## Uso: godot_console --headless --path . -s res://tools/smoke_menu_music.gd

var _time := 0.0


func _initialize() -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 150.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _until(condition: Callable, seconds := 5.0) -> bool:
	var limit := _time + seconds
	while not condition.call():
		if _time > limit:
			return false
		await process_frame
	return true


func _run() -> void:
	await process_frame
	var menu := current_scene
	var music = menu.get_node_or_null("Music")
	if not _check(music != null and music.get_child_count() == 2, "o menu tem a trilha (base + pulso)"): return
	var base: AudioStreamPlayer = music.get_child(0)
	var layer: AudioStreamPlayer = music.get_child(1)
	var bus_music: String = load("res://scripts/audio/audio_director.gd").MUSIC_BUS
	if not _check(base.playing and layer.playing and base.bus == bus_music and layer.bus == bus_music, "as duas camadas tocam no barramento de Música"): return
	if not _check(base.stream.data.size() == layer.stream.data.size(), "as camadas têm o mesmo tamanho (ficam em compasso)"): return

	# Começa suave: a base sobe, o pulso fica quieto
	if not _check(await _until(func(): return base.volume_db > -22.0, 5.0), "a base sobe até o volume do menu"): return
	if not _check(layer.volume_db <= -39.0 and not music.deep, "o pulso ainda não entrou"): return

	# Abrir uma tela faz entrar o instrumento novo; fechar a tela não o tira
	menu.get_node("Box/Dock/Civilizations").pressed.emit()
	if not _check(music.deep, "abrir uma tela marca a trilha como mais cheia"): return
	if not _check(await _until(func(): return layer.volume_db > -26.0, 5.0), "a camada de pulso entra"): return
	menu.get_node("Screen").close()
	await process_frame
	if not _check(music.deep and layer.volume_db > -26.0, "fechar a tela não tira o instrumento"): return

	# JOGAR: a música abaixa junto com o mergulho
	menu.approach_seconds = 1.0
	menu.get_node("Box/Play").pressed.emit()
	if not _check(music.leaving, "JOGAR marca a saída da trilha"): return
	if not _check(await _until(func(): return base.volume_db < -28.0, 2.0), "a base abaixa durante o mergulho"): return
	# espera a partida carregar (sair no meio da carga em segundo plano gera ERROR de recurso)
	if not _check(await _until(func(): return current_scene != null and current_scene.name != "Menu", 100.0), "o mergulho termina na partida"): return
	for i in 5:
		await process_frame
	print("OK smoke_menu_music")
	quit(0)
