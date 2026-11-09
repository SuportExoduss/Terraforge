extends SceneTree
## Teste de fumaça do Passo 34 (configurações, UI-006 / DD-132): (1) padrões; (2) mudar volume/qualidade aplica na hora
## nos barramentos e na janela, com limites e chave desconhecida ignorada; (3) o que o jogador escolhe fica salvo no
## Profile e volta ao reabrir; (4) a tela de configurações mexe nos mesmos ajustes (salva ao soltar o controle) e avisa
## ao fechar; (5) o menu tem o botão, abre/fecha a tela e aplica os ajustes salvos ao iniciar.
## Usa um arquivo de perfil só dele (não suja o perfil de verdade nem o dos outros testes).
## Uso: godot_console --headless --path . -s res://tools/smoke_settings.gd

const PROFILE_FILE := "user://profile_smoke_settings.json"

var _settings: Script
var _failed := false
var _closed := false


func _initialize() -> void:
	_settings = load("res://scripts/core/settings.gd")
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		_cleanup()
		quit(1)


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_FILE))


func _saved(key: String) -> Variant:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_FILE))
	return parsed.get("settings", {}).get(key, null) if parsed is Dictionary else null


func _bus_db(bus_name: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))


func _run() -> void:
	var profile: Script = load("res://scripts/core/profile.gd")
	profile.path = PROFILE_FILE
	_cleanup()
	profile.load_data()

	# 1. Padrões
	_check(is_equal_approx(_settings.get_value("sfx"), 1.0), "efeitos: padrão 1.0")
	_check(is_equal_approx(_settings.get_value("music"), 0.8), "música: padrão 0.8")
	_check(int(_settings.get_value("quality")) == 2, "qualidade: padrão ALTA")

	# 2. Aplicação na hora, limites e chave desconhecida
	_settings.set_value("sfx", 0.5)
	_check(absf(_bus_db("SFX") - linear_to_db(0.5)) < 0.01, "o volume dos efeitos não chegou ao barramento (%.2f dB)" % _bus_db("SFX"))
	_settings.set_value("music", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Música")), "música em 0 deve silenciar o barramento")
	_settings.set_value("music", 0.6)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Música")) and absf(_bus_db("Música") - linear_to_db(0.6)) < 0.01, "música 0.6 deve voltar a soar")
	_settings.set_value("sfx", 5.0)
	_check(is_equal_approx(_settings.get_value("sfx"), 1.0), "volume acima de 1 deve ser limitado")
	_settings.set_value("sfx", -2.0)
	_check(is_equal_approx(_settings.get_value("sfx"), 0.0), "volume abaixo de 0 deve ser limitado")
	_settings.set_value("sfx", 0.5)
	_settings.set_value("quality", 0)
	_check(is_equal_approx(root.scaling_3d_scale, 0.7) and root.msaa_3d == Viewport.MSAA_DISABLED, "qualidade BAIXA: resolução 3D e antisserrilhado")
	_settings.set_value("quality", 1)
	_check(is_equal_approx(root.scaling_3d_scale, 0.85) and root.msaa_3d == Viewport.MSAA_2X, "qualidade MÉDIA")
	_settings.set_value("quality", 9)
	_check(int(_settings.get_value("quality")) == 2 and is_equal_approx(root.scaling_3d_scale, 1.0) and root.msaa_3d == Viewport.MSAA_4X, "qualidade acima do máximo vira ALTA")
	_settings.set_value("inexistente", 1.0)
	_check(not profile.data["settings"].has("inexistente"), "chave desconhecida deve ser ignorada")

	# 3. Persistência
	_settings.set_value("quality", 1)
	_check(is_equal_approx(_saved("sfx"), 0.5) and is_equal_approx(_saved("music"), 0.6) and int(_saved("quality")) == 1, "os ajustes não foram salvos no perfil")
	profile.data = profile.defaults()
	_check(is_equal_approx(_settings.get_value("sfx"), 1.0), "perfil novo volta aos padrões")
	profile.load_data()
	_check(is_equal_approx(_settings.get_value("sfx"), 0.5) and int(_settings.get_value("quality")) == 1, "reabrir o perfil deve devolver os ajustes")
	_settings.set_value("sfx", 0.9, false)
	_check(is_equal_approx(_saved("sfx"), 0.5), "com save = false o arquivo não muda (arrastar o controle)")
	_settings.set_value("sfx", 0.5)

	# 4. A tela de configurações
	var panel: Control = load("res://scripts/ui/settings_panel.gd").new()
	panel.closed.connect(func(): _closed = true)
	root.add_child(panel)
	await process_frame
	var sfx: HSlider = panel.find_child("Sfx", true, false)
	var music: HSlider = panel.find_child("Music", true, false)
	_check(sfx != null and music != null, "a tela deve ter os dois controles de volume")
	_check(is_equal_approx(sfx.value, 0.5) and is_equal_approx(music.value, 0.6), "os controles devem mostrar os valores atuais")
	var low: Button = panel.find_child("Q0", true, false)
	var middle: Button = panel.find_child("Q1", true, false)
	var high: Button = panel.find_child("Q2", true, false)
	_check(low != null and middle != null and high != null, "a tela deve ter os três níveis de qualidade")
	_check(middle.button_pressed and not low.button_pressed and not high.button_pressed, "o nível atual deve vir marcado")
	sfx.value = 0.25
	_check(is_equal_approx(_settings.get_value("sfx"), 0.25) and absf(_bus_db("SFX") - linear_to_db(0.25)) < 0.01, "arrastar o controle deve aplicar na hora")
	_check(is_equal_approx(_saved("sfx"), 0.5), "arrastando, ainda não salva")
	sfx.drag_ended.emit(true)
	_check(is_equal_approx(_saved("sfx"), 0.25), "soltar o controle deve salvar")
	low.pressed.emit()
	_check(int(_settings.get_value("quality")) == 0 and is_equal_approx(root.scaling_3d_scale, 0.7), "o botão de qualidade deve aplicar")
	_check(int(_saved("quality")) == 0, "o botão de qualidade deve salvar")
	panel.find_child("Back", true, false).pressed.emit()
	_check(_closed, "VOLTAR deve avisar que fechou")
	panel.free()

	# 5. O menu abre/fecha a tela e aplica o que está salvo ao iniciar
	_settings.set_value("sfx", 0.3)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 0.0)   # como se o jogo acabasse de abrir
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(absf(_bus_db("SFX") - linear_to_db(0.3)) < 0.01, "o menu deve aplicar os ajustes salvos ao iniciar (%.2f dB)" % _bus_db("SFX"))
	var button: Button = menu.find_child("Settings", true, false)
	_check(button != null and button.text == "CONFIGURAÇÕES", "o menu deve ter o botão CONFIGURAÇÕES")
	button.pressed.emit()
	await process_frame
	var opened: Control = menu.find_child("SettingsPanel", true, false)
	_check(opened != null and opened.is_visible_in_tree(), "o botão deve abrir a tela de configurações")
	opened.find_child("Back", true, false).pressed.emit()
	await process_frame
	_check(menu.find_child("SettingsPanel", true, false) == null, "VOLTAR deve fechar a tela e voltar ao menu")

	_cleanup()
	if not _failed:
		print("OK")
		quit(0)
