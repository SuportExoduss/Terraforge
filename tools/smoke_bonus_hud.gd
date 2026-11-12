extends SceneTree
## Teste de fumaça dos Passos 80–82 (SYS-005 INTERFACE: "ícone exclusivo, contador, indicador de duração, animação de ativação"):
## (80) cada bônus ativo tem na coluna da HUD uma ficha com cor e símbolo só dele; (81) o bônus temporário tem uma barra
## que esvazia, o instantâneo não tem barra.
## Uso: godot_console --headless --path . -s res://tools/smoke_bonus_hud.gd

const TEST_PROFILE := "user://profile_smoke_bonus_hud.json"
const KINDS := ["VELOCIDADE", "RECUPERAÇÃO", "VIDA EXTRA", "CONGELAMENTO", "ESCUDO TEMPORAL", "CONGELADO"]

var _match: Node
var _hud: Node
var _bus: Node
var _time := 0.0


func _initialize() -> void:
	load("res://scripts/core/profile.gd").path = TEST_PROFILE   # o ajuste "reduzir movimento" não suja o perfil de verdade
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	root.add_child(_match)
	_hud = _match.get_node("Hud")
	_bus = root.get_node("EventBus")
	_run()


func _process(delta: float) -> bool:
	_time += delta
	if _time > 90.0:
		print("FALHOU: tempo esgotado")
		quit(1)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(TEST_PROFILE)
		quit(1)
	return ok


func _row(kind: String) -> Control:
	return _hud.find_child("Row_" + kind, true, false) as Control


func _chip(kind: String) -> Control:
	return _row(kind).find_child("Chip", true, false) as Control


func _run() -> void:
	await root.get_node("EventBus").match_started
	await process_frame

	# 80. Uma ficha por bônus: cor e símbolo diferentes entre si; outro dono é ignorado
	_bus.bonus_activated.emit(2, "VELOCIDADE", 8.0)
	if not _check(_row("VELOCIDADE") == null, "o bônus de outro dono não deveria aparecer"): return
	var colors := {}
	var glyphs := {}
	for kind in KINDS:
		_bus.bonus_activated.emit(1, kind, 8.0)
		var chip := _chip(kind)
		if not _check(chip != null and chip.visible, "%s: ficha na coluna" % kind): return
		colors[chip.get_theme_stylebox("panel").bg_color] = true
		glyphs[(chip.find_child("Glyph", true, false) as Label).text] = true
	if not _check(colors.size() == KINDS.size() and glyphs.size() == KINDS.size(), "cada bônus tem cor e símbolo próprios (%d cores, %d símbolos)" % [colors.size(), glyphs.size()]): return
	if not _check(is_equal_approx(_chip("VELOCIDADE").get_theme_stylebox("panel").bg_color.r, load("res://scripts/world/bonus_system.gd").COLORS[0].r), "a ficha usa a cor do cristal"): return
	if not _check((_row("VELOCIDADE").find_child("Bonus", true, false) as Label).text.begins_with("VELOCIDADE"), "o contador continua ao lado da ficha"): return

	# 81. Barra de duração: cheia no começo, esvazia; o instantâneo não tem barra
	var bar := _row("VELOCIDADE").find_child("Bar", true, false) as ProgressBar
	if not _check(bar.visible and bar.value > 0.95, "bônus temporário: barra cheia no começo (%.2f)" % bar.value): return
	await create_timer(1.2).timeout
	if not _check(bar.value < 0.95 and bar.value > 0.6, "a barra esvazia com o tempo (%.2f após 1,2 s de 8 s)" % bar.value): return
	_bus.bonus_activated.emit(1, "VIDA EXTRA", 0.0)
	if not _check(not (_row("VIDA EXTRA").find_child("Bar", true, false) as Control).visible, "bônus instantâneo: sem barra"): return
	_bus.bonus_activated.emit(1, "VIDA EXTRA", 8.0)
	if not _check((_row("VIDA EXTRA").find_child("Bar", true, false) as Control).visible, "voltando a ser temporário a barra reaparece"): return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
