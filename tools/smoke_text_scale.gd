extends SceneTree
## Teste de fumaça do Passo 66 (UI-006, "boa acessibilidade"): o ajuste TEXTO (100%–150%) das configurações existe na tela,
## é limitado, fica salvo e aumenta os textos da HUD montada depois; padrão = tamanhos de sempre.
## Usa um arquivo de perfil só dele. Uso: godot_console --headless --path . -s res://tools/smoke_text_scale.gd

const PROFILE_FILE := "user://profile_smoke_text_scale.json"

var _failed := false


func _initialize() -> void:
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		_cleanup()
		quit(1)


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_FILE))


func _font(hud: Node, label_name: String) -> int:
	return (hud.find_child(label_name, true, false) as Label).get_theme_font_size("font_size")


func _run() -> void:
	var profile: Script = load("res://scripts/core/profile.gd")
	var settings: Script = load("res://scripts/core/settings.gd")
	var hud_script: Script = load("res://scripts/ui/hud.gd")
	profile.path = PROFILE_FILE
	_cleanup()
	profile.load_data()

	# 1. Padrão = 100%; HUD com os tamanhos de sempre
	_check(is_equal_approx(settings.text_scale(), 1.0), "padrão deveria ser 100%% (%.2f)" % settings.text_scale())
	var hud: Node = hud_script.new()
	root.add_child(hud)
	await process_frame
	_check(_font(hud, "ClockLabel") == 30 and _font(hud, "ScoreLabel") == 18, "padrão: relógio 30 / domínio 18 (%d / %d)" % [_font(hud, "ClockLabel"), _font(hud, "ScoreLabel")])
	hud.queue_free()
	await process_frame

	# 2. Limites e persistência
	settings.set_value("text", 1.0)
	_check(is_equal_approx(settings.text_scale(), 1.5), "máximo = 150%% (%.2f)" % settings.text_scale())
	settings.set_value("text", 9.0)
	_check(is_equal_approx(settings.text_scale(), 1.5), "acima do máximo é limitado a 150%")
	settings.set_value("text", -1.0)
	_check(is_equal_approx(settings.text_scale(), 1.0), "abaixo do mínimo é limitado a 100%")
	settings.set_value("text", 1.0)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_FILE))
	_check(saved is Dictionary and is_equal_approx(float(saved["settings"].get("text", -1.0)), 1.0), "o ajuste deveria ficar salvo no perfil")

	# 3. HUD montada com 150%: textos maiores, evento desce junto com o relógio
	hud = hud_script.new()
	root.add_child(hud)
	await process_frame
	_check(_font(hud, "ClockLabel") == 45 and _font(hud, "ScoreLabel") == 27 and _font(hud, "EventLabel") == 39, "150%%: relógio 45 / domínio 27 / evento 39 (%d / %d / %d)" % [_font(hud, "ClockLabel"), _font(hud, "ScoreLabel"), _font(hud, "EventLabel")])
	var clock: Label = hud.find_child("ClockLabel", true, false)
	var event: Label = hud.find_child("EventLabel", true, false)
	_check(event.position.y > clock.position.y + clock.get_theme_font_size("font_size"), "o evento deveria ficar abaixo do relógio maior")
	hud.queue_free()

	# 4. A tela de configurações tem o controle e ele mexe no mesmo ajuste
	settings.set_value("text", 0.0)
	var panel: Control = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await process_frame
	var slider := panel.find_child("Text", true, false) as HSlider
	_check(slider != null and is_equal_approx(slider.value, 0.0), "a tela deveria ter o controle TEXTO em 0")
	if slider != null:
		slider.value = 0.5
		_check(is_equal_approx(settings.text_scale(), 1.25), "controle em 0,5 = 125%% (%.2f)" % settings.text_scale())

	if not _failed:
		print("OK: ajuste TEXTO 100%–150% com limites, salvo, na tela de configurações e aplicado nos textos da HUD")
		_cleanup()
		quit(0)
