extends SceneTree
## Teste de fumaça do Passo 74 (SYS-003 "perder uma vida causa tensão e impacto", DD-021): ao perder vida a HUD acende um
## clarão vermelho em tela cheia que some sozinho; mais pontos = mais forte; dano de outro dono, dano absorvido pelo
## escudo e o ajuste "Reduzir movimento" (Passo 56) não acendem nada; o clarão nunca engole o toque.
## Uso: godot_console --headless --path . -s res://tools/smoke_damage_flash.gd

var _match: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 30.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)


func _run() -> void:
	await _bus.match_started
	for i in 5:
		await process_frame
	var rect := _match.get_node("Hud").find_child("DamageFlash", true, false) as ColorRect
	_check(rect != null, "falta o DamageFlash na HUD")
	_check(rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "o clarão não pode engolir o toque")
	var health: Node
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == 1:
			health = r.get_node("Health")
	_check(health != null, "corredor do jogador não achado")
	health.shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	_check(rect.color.a == 0.0, "o clarão deveria começar apagado (%.2f)" % rect.color.a)

	health.take_damage(1, "VULCÃO")
	var weak := rect.color.a
	_check(weak > 0.1, "perder 1 ponto deveria acender o clarão (%.2f)" % weak)
	await create_timer(0.6).timeout   # some sozinho
	_check(rect.color.a == 0.0, "o clarão deveria apagar (%.2f)" % rect.color.a)

	health.take_damage(4, "IMPACTO")
	_check(rect.color.a > weak, "4 pontos deveriam piscar mais forte que 1 (%.2f > %.2f)" % [rect.color.a, weak])
	await create_timer(0.6).timeout
	_check(rect.color.a == 0.0, "o clarão deveria apagar de novo (%.2f)" % rect.color.a)

	_bus.damage_taken.emit(2, 3, "FURACÃO")   # outro dono: nada
	_check(rect.color.a == 0.0, "dano alheio acendeu o clarão (%.2f)" % rect.color.a)
	health.grant_shield(5.0)
	health.take_damage(1, "TSUNAMI")   # absorvido: nada
	_check(rect.color.a == 0.0, "dano absorvido pelo escudo acendeu o clarão (%.2f)" % rect.color.a)

	health.shield_left = 0.0
	var settings = load("res://scripts/core/settings.gd")
	settings.set_value("reduce_motion", 1.0, false)
	health.take_damage(1, "TERREMOTO")
	var cause := (_match.get_node("Hud").find_child("CauseLabel", true, false) as Label).text
	settings.set_value("reduce_motion", 0.0, false)
	_check(rect.color.a == 0.0, "com Reduzir movimento não pode haver clarão (%.2f)" % rect.color.a)
	_check(cause == "-1  TERREMOTO", "a legenda continua com Reduzir movimento: '%s'" % cause)
	print("OK")
	quit(0)
