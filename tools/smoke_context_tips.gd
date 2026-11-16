extends SceneTree
## Teste de fumaça do Passo 130 (DD-169): DICAS DE CONTEXTO nas primeiras partidas normais. (1) em partida normal (`remember`) as
## dicas de largada/lembrete do treino NÃO saem, e as de contexto saem na hora certa: cortar um rival, vida em 1, âncora perdida,
## base tomada (a sua) e base conquistada; o que acontece com os outros não gera dica; (2) cada dica sai uma vez na vida: o perfil
## guarda os ids como TEXTO, sobrevive a salvar/recarregar, e uma nova partida não repete; (3) o treino também registra, mas relê
## tudo (não pula dica já vista); (4) a HUD só cria o Coach no treino ou até MEMORY_MATCHES partidas (e `remember` só fora do treino).
## Uso: godot_console --headless --path . -s res://tools/smoke_context_tips.gd

const COACH := "res://scripts/ui/tutorial_coach.gd"
const FILE := "user://profile_smoke_context_tips.json"

var _failed := false


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(FILE)
		quit(1)


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _fresh_profile(matches: int) -> void:
	Profile.path = FILE
	Profile.data = Profile.defaults()
	Profile.data["matches"] = matches
	Profile.save()


func _coach(remember: bool) -> Control:
	var coach: Control = load(COACH).new()
	coach.set("remember", remember)
	root.add_child(coach)
	return coach


func _run() -> void:
	var bus: Node = root.get_node("EventBus")
	_fresh_profile(3)

	# 1. Partida normal: só as dicas de contexto, nas horas certas
	var coach := _coach(true)
	await _frames(2)
	bus.match_started.emit()
	coach._process(100.0)
	_check(coach.shown.is_empty(), "a largada e o lembrete do circuito são do treino: nada em partida normal (saiu %s)" % [coach.shown])
	bus.trail_cut.emit(1, 2)   # cortaram o MEU rastro: isso é o "hurt", não o "cut"
	bus.trail_cut.emit(2, 3)   # dois bots
	bus.health_changed.emit(2, 1, 6)   # vida de um bot
	bus.health_changed.emit(1, 3, 6)
	bus.trail_anchor_lost.emit(2)
	bus.base_fallen.emit(3, 2)   # um bot tomou a base de outro
	_check(coach.shown.is_empty(), "o que acontece com os outros (ou vida folgada) não gera dica (saiu %s)" % [coach.shown])
	bus.trail_cut.emit(2, 1)
	_check(Array(coach.shown) == ["cut"] and coach.current_text().contains("cortou o rastro"), "cortar um rival deveria dar a dica 'cut' (saiu %s)" % [coach.shown])
	bus.health_changed.emit(1, 1, 6)
	bus.trail_anchor_lost.emit(1)
	bus.base_fallen.emit(1, 2)
	bus.base_fallen.emit(2, 1)
	_check(Array(coach.shown) == ["cut", "lowhp", "anchor", "fallen", "conquer"], "ordem das dicas de contexto inesperada: %s" % [coach.shown])
	bus.trail_cut.emit(2, 1)
	bus.health_changed.emit(1, 1, 6)
	_check(coach.shown.size() == 5, "cada dica sai uma única vez (saíram %d)" % coach.shown.size())
	var ids: Array = Profile.data["tips_seen"]
	_check(ids == ["cut", "lowhp", "anchor", "fallen", "conquer"], "o perfil deveria guardar as 5 dicas vistas (guardou %s)" % [ids])
	for id in ids:
		_check(id is String, "os ids das dicas vistas são texto (o JSON troca número 5 por 5.0)")

	# 2. Salvar, recarregar e jogar outra partida: nada repete; o que ainda não saiu sai
	Profile.save()
	Profile.load_data()
	_check(Profile.data["tips_seen"] == ids, "as dicas vistas deveriam sobreviver a salvar e recarregar (voltou %s)" % [Profile.data["tips_seen"]])
	coach.queue_free()
	await _frames(2)
	var next := _coach(true)
	await _frames(2)
	bus.trail_cut.emit(2, 1)
	bus.base_fallen.emit(1, 2)
	_check(next.shown.is_empty(), "uma dica já vista em outra partida não volta (saiu %s)" % [next.shown])
	bus.global_event_warning.emit("CHUVA DE METEOROS", 5)
	bus.bonus_stock_changed.emit(1, ["ESCUDO TEMPORAL"])
	_check(Array(next.shown) == ["event", "bonus"], "as que ainda não saíram (evento, bônus) saem na partida normal (saiu %s)" % [next.shown])
	next.queue_free()
	await _frames(2)

	# 3. O treino: registra, mas relê tudo (não pula dica já vista)
	_fresh_profile(0)
	Profile.data["tips_seen"] = ["steer"]
	var training := _coach(false)
	await _frames(2)
	bus.match_started.emit()
	_check(Array(training.shown) == ["steer"], "o treino mostra a largada mesmo se o perfil já a tem (saiu %s)" % [training.shown])
	bus.territory_loop_claimed.emit(1, 50)
	_check(Profile.data["tips_seen"] == ["steer", "claimed"], "o treino registra o que mostra, sem repetir o id (ficou %s)" % [Profile.data["tips_seen"]])
	training.queue_free()
	await _frames(2)

	# 4. A HUD só cria o Coach no treino ou nas primeiras partidas
	var services: Node = root.get_node("Services")
	var normal: Resource = load("res://scripts/core/planet_def.gd").by_id("medio")
	var training_def: Resource = load("res://scripts/core/planet_def.gd").training()
	var theme: Theme = load("res://scripts/ui/ui_theme.gd").build()
	var cases := [
		["treino", training_def, 0, true, false],
		["normal, 3 partidas", normal, 3, true, true],
		["normal, 7 partidas (a última)", normal, 7, true, true],
		["normal, 8 partidas (já conhece)", normal, 8, false, false],
		["normal, 40 partidas", normal, 40, false, false],
	]
	for case in cases:
		_fresh_profile(case[2])
		services.match_def = case[1]
		var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
		root.add_child(hud)
		await _frames(2)
		var made: Node = hud.get_node_or_null("Root/Coach")
		_check((made != null) == case[3], "%s: Coach criado = %s (esperado %s)" % [case[0], made != null, case[3]])
		if made != null:
			_check(made.get("remember") == case[4], "%s: remember = %s (esperado %s)" % [case[0], made.get("remember"), case[4]])
		hud.queue_free()
		await _frames(2)
	services.match_def = null
	DirAccess.remove_absolute(FILE)
	if not _failed:
		print("OK")
		quit(0)
