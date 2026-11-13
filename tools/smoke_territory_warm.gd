extends SceneTree
## Passo 92: a grade do território montada numa thread (TerritoryMap.warm) é IDÊNTICA à montada na hora e a partida só a copia.
## Uso: godot_console --headless --path . -s res://tools/smoke_territory_warm.gd

func _initialize() -> void:
	var cls: GDScript = load("res://scripts/world/territory_map.gd")   # load(): um -s compila antes dos autoloads existirem
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	var radius: float = main_scene.get_node("Planet").radius
	cls.warm(radius)   # o que o menu faz...
	while not WorkerThreadPool.is_task_completed(cls._warm_task):
		OS.delay_msec(20)   # ...e o jogador escolhe com calma: quando a partida começa, a grade já está pronta
	main_scene.get_node("HomeBase").skip_ceremony()
	root.add_child(main_scene)
	for i in 5:
		await process_frame   # o planeta se registra em Services no _ready dele
	var map: Node = root.get_node("Main/Territory")
	var cold: Node = cls.new()
	cold._radius = radius
	var t := Time.get_ticks_usec()
	cold._build_grid()   # a montagem de sempre, sem thread
	var cold_ms := (Time.get_ticks_usec() - t) / 1000.0
	var ok := true
	ok = _check(map._built, "grade montada") and ok
	ok = _check(map._dirs == cold._dirs and map._nb_data == cold._nb_data and map._nb_start == cold._nb_start, "vizinhança e células iguais à montagem direta") and ok
	ok = _check(map._bucket_data == cold._bucket_data and map._bucket_start == cold._bucket_start and map._grid == cold._grid, "baldes iguais") and ok
	ok = _check(is_equal_approx(map.cell_spacing, cold.cell_spacing), "espaçamento igual") and ok
	ok = _check(map.build_msec < cold_ms * 0.25, "partida só copia (%.1f ms contra %.0f ms montando)" % [map.build_msec, cold_ms]) and ok
	cold.free()
	print("OK (grade em thread: %.1f ms na partida contra %.0f ms montando)" % [map.build_msec, cold_ms] if ok else "FALHOU")
	quit(0 if ok else 1)


func _check(cond: bool, what: String) -> bool:
	if not cond:
		print("  FALHA: ", what)
	return cond
