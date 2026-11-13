extends SceneTree
## Teste de fumaça do Passo 89 (desempenho): ModelCache segura o touro e a gema na memória. O 2º uso é instantâneo e devolve a mesma
## cena (load() solto relia o arquivo: 35 ms por sentinela). O menu pede os dois em segundo plano; scene() espera o que faltar.
## Uso: godot_console --headless --path . -s res://tools/smoke_model_cache.gd

func _initialize() -> void:
	var bad: Array[String] = []
	ModelCache.prefetch()   # pedido em thread; scene() logo em seguida tem de esperar e devolver o resultado, não nulo
	var bull := ModelCache.scene(ModelCache.BULL)
	var gem := ModelCache.scene(ModelCache.GEM)
	if bull == null or gem == null:
		bad.append("modelo nulo após prefetch (touro %s, gema %s)" % [bull, gem])
	else:
		var t := Time.get_ticks_usec()
		var again := ModelCache.scene(ModelCache.BULL)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		if again != bull:
			bad.append("o 2º scene() devolveu outra cena (não está segurando)")
		if ms > 2.0:
			bad.append("2º scene() levou %.1f ms (esperado < 2)" % ms)
		var body := bull.instantiate()
		if body.find_child("Skeleton3D", true, false) == null or body.find_child("AnimationPlayer", true, false) == null:
			bad.append("o touro perdeu Skeleton3D/AnimationPlayer")
		body.free()
	# load() em tempo de execução: os dois scripts citam o autoload EventBus, que ainda não existe quando um -s é compilado
	if load("res://scripts/world/defender_system.gd").BULL_PATH != ModelCache.BULL or load("res://scripts/world/bonus_system.gd").GEM_PATH != ModelCache.GEM:
		bad.append("DefenderSystem/BonusSystem não usam os caminhos do ModelCache")
	for b in bad:
		print("FALHOU: ", b)
	print("OK" if bad.is_empty() else "FALHOU")
	quit(0 if bad.is_empty() else 1)
