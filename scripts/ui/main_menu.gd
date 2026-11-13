class_name MainMenu
extends Control
## Menu inicial (cap. 04: Menu → partida → Resultados → Menu): título, perfil salvo (nível, XP, moedas), JOGAR, CONFIGURAÇÕES (UI-006) e SAIR.
## ponytail: sem lobby nem matchmaking — a partida usa os padrões do MatchSetup (3 adversários); entram com o multiplayer.

const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"

var approach_seconds := 1.8   # duração do mergulho no planeta ao clicar JOGAR
var _launching := false


func _ready() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()   # `--server` vale antes ou depois do `--`
	if DedicatedServer.requested(args):   # servidor dedicado (DD-134): sem menu, o processo vira a sala
		var server := DedicatedServer.new()
		server.configure(args)
		get_tree().root.add_child.call_deferred(server)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.05, 0.12)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var backdrop := PlanetBackdrop.new()   # abertura viva (DD-006): o planeta vem antes da interface
	backdrop.name = "Backdrop"
	add_child(backdrop)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "TERRAFORGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)

	Profile.load_data()
	Settings.apply_all()   # volumes e qualidade salvos valem desde o menu
	SoundBank.warm()   # Passo 90: música e efeitos são sintetizados numa thread enquanto o jogador escolhe
	TerritoryMap.warm()   # Passo 92: a grade do território (~600 ms de GDScript) é montada numa thread enquanto o jogador escolhe
	ModelCache.prefetch()   # Passo 89: touro e gema carregam em segundo plano enquanto o jogador escolhe; a partida os pega prontos
	ResourceLoader.load_threaded_request(MATCH_SCENE)   # idem a partida: no JOGAR ela já vem andada (o pedido repetido é inofensivo)
	var music := MenuMusic.new()   # trilha suave; entra mais um instrumento a cada tela aberta
	music.name = "Music"
	add_child(music)
	var profile := Label.new()
	profile.name = "Profile"
	profile.text = _profile_text()
	profile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile.add_theme_font_size_override("font_size", 20)
	box.add_child(profile)

	var play := _add_button(box, "Play", "JOGAR", _play)
	var dock := HBoxContainer.new()   # atalhos das telas do menu
	dock.name = "Dock"
	dock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dock.add_theme_constant_override("separation", 8)
	box.add_child(dock)
	_add_dock(dock, "Profile", "PERFIL", ProfileScreen)
	_add_dock(dock, "Civilizations", "CIVILIZAÇÕES", CivilizationsScreen)
	_add_dock(dock, "Shop", "LOJA", ShopScreen)
	_add_dock(dock, "Online", "ONLINE", OnlineScreen)
	_add_dock(dock, "Events", "EVENTOS", EventsScreen)
	_add_button(box, "Settings", "CONFIGURAÇÕES", _open_settings)
	_add_button(box, "Quit", "SAIR", func(): get_tree().quit())
	play.grab_focus()   # teclado / controle


## Primeiro clique (DD-007): a interface some, a câmera mergulha no planeta e a partida carrega em segundo plano;
## a troca de cena só acontece com os dois prontos. `approach_seconds` = 0 vai direto (testes).
func _play() -> void:
	if _launching:
		return
	_launching = true
	get_node("Music").fade_out(maxf(approach_seconds, 0.2))
	if approach_seconds <= 0.0:
		get_tree().change_scene_to_file(MATCH_SCENE)
		return
	ResourceLoader.load_threaded_request(MATCH_SCENE)
	var box: Control = get_node("Box")
	box.process_mode = Node.PROCESS_MODE_DISABLED   # nenhum botão responde durante a descida
	create_tween().tween_property(box, "modulate:a", 0.0, minf(0.5, approach_seconds))
	await get_node("Backdrop").approach(approach_seconds)
	while ResourceLoader.load_threaded_get_status(MATCH_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var scene := ResourceLoader.load_threaded_get(MATCH_SCENE) as PackedScene
	if scene != null:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(MATCH_SCENE)   # a carga falhou: tenta do jeito simples (e mostra o erro)


func _open_settings() -> void:
	get_node("Music").deepen()
	var panel := SettingsPanel.new()
	panel.name = "SettingsPanel"
	panel.closed.connect(func():
		panel.queue_free()
		get_node("Box/Settings").grab_focus())
	add_child(panel)


func _profile_text() -> String:
	return "Nível %d  ·  %d XP  ·  %d moedas  ·  %d partidas  ·  conquistas %d/%d" % [Profile.level(), Profile.data["xp"], Profile.data["coins"], Profile.data["matches"], Profile.data["achievements"].size(), Achievements.LIST.size()]


func _add_dock(dock: Control, button_name: String, label: String, screen_class: GDScript) -> void:
	var button := _add_button(dock, button_name, label, func(): _open_screen(screen_class.new(), button_name))
	button.custom_minimum_size = Vector2(150.0, 44.0)
	button.add_theme_font_size_override("font_size", 16)


## Abre uma tela do menu por cima; o corpo do menu fica parado (sem foco nem cliques) até ela fechar.
func _open_screen(screen: MenuScreen, return_to: String) -> void:
	get_node("Music").deepen()
	var box: Control = get_node("Box")
	box.process_mode = Node.PROCESS_MODE_DISABLED
	screen.name = "Screen"
	screen.closed.connect(func():
		screen.queue_free()
		box.process_mode = Node.PROCESS_MODE_INHERIT
		get_node("Box/Profile").text = _profile_text()   # a loja pode ter gastado moedas
		get_node("Box/Dock/" + return_to).grab_focus())
	add_child(screen)


func _add_button(parent: Control, button_name: String, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.custom_minimum_size = Vector2(240.0, 56.0)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
