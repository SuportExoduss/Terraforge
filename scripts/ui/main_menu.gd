class_name MainMenu
extends Control
## Menu inicial (cap. 04: Menu → partida → Resultados → Menu): título, perfil salvo (nível, XP, moedas), JOGAR, CONFIGURAÇÕES (UI-006) e SAIR.
## ponytail: sem lobby nem matchmaking — a partida usa os padrões do MatchSetup (3 adversários); entram com o multiplayer.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const DailyMissions := preload("res://scripts/core/daily_missions.gd")
const Leagues := preload("res://scripts/core/leagues.gd")
const MissionsScreen := preload("res://scripts/ui/missions_screen.gd")
const SeasonPass := preload("res://scripts/core/season_pass.gd")
const PassScreen := preload("res://scripts/ui/pass_screen.gd")
const PlanetScreen := preload("res://scripts/ui/planet_screen.gd")
const SafeArea := preload("res://scripts/core/safe_area.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/match.tscn"

const TOUCH_MIN := 48.0   # Passo 129: altura mínima de um botão para o dedo (≈ 6 mm no celular de 6")
const EXIT_WINDOW_MSEC := 2000   # Passo 128: dois VOLTAR dentro disto saem do jogo

var approach_seconds := 1.8   # duração do mergulho no planeta ao clicar JOGAR
var quit_action: Callable = _quit_game   # o teste troca (sair de verdade encerraria o teste)
var _launching := false
var _back_msec := -100000
var _hint_tween: Tween


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
	add_child(UiTheme.left_shade())   # Passo 109: sombra à esquerda dá contraste ao texto; o planeta fica livre à direita

	var box := VBoxContainer.new()   # coluna à esquerda, centrada na vertical (o planeta grande ocupa o lado direito)
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	var inset := SafeArea.insets(self)   # Passo 129: a coluna fica na área segura (entalhe à esquerda, barra de gestos embaixo)
	box.offset_left = 48.0 + inset.x
	box.offset_right = 448.0 + inset.x
	box.offset_top = (inset.y - inset.w) * 0.5
	box.offset_bottom = box.offset_top
	box.grow_horizontal = Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 8)   # com os botões de 48 px a coluna ainda cabe nos 540 px
	add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "TERRAFORGE"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 50)
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
	profile.theme_type_variation = "ProfileLabel"
	profile.add_theme_font_size_override("font_size", 16)
	_dress_profile(profile)
	box.add_child(profile)

	var first_time: bool = int(Profile.data.get("matches", 0)) == 0   # Passo 106: a primeira partida é o treino, sem escolha
	Services.match_def = PlanetDef.training() if first_time else PlanetDef.by_id(str(Profile.data.get("planet", "medio")))   # DD-143: o último planeta escolhido
	var play := _add_button(box, "Play", "JOGAR", _play, 64.0, 30)   # a única ação em âmbar: o olho vai direto para ela
	play.theme_type_variation = "PrimaryButton"
	var planet := _add_button(box, "Planet", "", func(): _open_screen(PlanetScreen.new(), "Planet"), TOUCH_MIN, 14)   # Passo 125: abre a escolha de planeta
	planet.disabled = first_time
	_refresh_planet(first_time)
	_add_button(box, "Pass", "", func(): _open_screen(PassScreen.new(), "Pass"), TOUCH_MIN, 14)   # Passo 123: faixa do passe de temporada
	_refresh_pass_label()
	var dock := GridContainer.new()   # atalhos das telas do menu (3 por linha)
	dock.name = "Dock"
	dock.columns = 3
	dock.add_theme_constant_override("h_separation", 8)
	dock.add_theme_constant_override("v_separation", 8)
	box.add_child(dock)
	_add_dock(dock, "Profile", "PERFIL", ProfileScreen)
	_add_dock(dock, "Civilizations", "CIVILIZAÇÕES", CivilizationsScreen)
	_add_dock(dock, "Shop", "LOJA", ShopScreen)
	_add_dock(dock, "Online", "ONLINE", OnlineScreen)
	_add_dock(dock, "Events", "EVENTOS", EventsScreen)
	_add_dock(dock, "Missions", "MISSÕES", MissionsScreen)
	_refresh_missions_badge()
	var footer := HBoxContainer.new()   # Passo 129: CONFIGURAÇÕES e SAIR lado a lado: os dois com altura de dedo e a coluna cabe em 540 px
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	var settings := _add_button(footer, "Settings", "CONFIGURAÇÕES", _open_settings, TOUCH_MIN, 15)
	settings.theme_type_variation = "GhostButton"
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.size_flags_stretch_ratio = 2.0
	var quit := _add_button(footer, "Quit", "SAIR", func(): get_tree().quit(), TOUCH_MIN, 15)
	quit.theme_type_variation = "GhostButton"
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.grab_focus()   # teclado / controle


## Passo 125: o botão mostra o planeta escolhido e o brilho da atmosfera do fundo acompanha o bioma.
func _refresh_planet(first_time := false) -> void:
	get_node("Box/Planet").text = ("PRIMEIRA PARTIDA: " if first_time else "PLANETA: ") + Services.match_def.summary()
	get_node("Backdrop").set_biome(Services.match_def.biome)


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
	var loading := Label.new()   # Passo 94: o mergulho acaba na tela preta; a espera que sobra (carga + montagem da partida) ganha aviso, não imagem congelada
	loading.name = "Loading"
	loading.text = "PREPARANDO A PARTIDA…"
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading.add_theme_font_size_override("font_size", 28)
	add_child(loading)
	await get_tree().process_frame   # dois quadros: o aviso é pintado ANTES do quadro longo da troca de cena
	await get_tree().process_frame
	while ResourceLoader.load_threaded_get_status(MATCH_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var scene := ResourceLoader.load_threaded_get(MATCH_SCENE) as PackedScene
	if scene != null:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(MATCH_SCENE)   # a carga falhou: tenta do jeito simples (e mostra o erro)


## Passo 128: VOLTAR/ESC aqui avisa e, repetido em 2 s, sai. As telas abertas por cima tratam o próprio voltar antes (e engolem o evento).
func _unhandled_input(event: InputEvent) -> void:
	if _launching or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	var now := Time.get_ticks_msec()
	if now - _back_msec <= EXIT_WINDOW_MSEC:
		quit_action.call()
		return
	_back_msec = now
	var hint := get_node_or_null("ExitHint") as Label
	if hint == null:
		hint = Label.new()
		hint.name = "ExitHint"
		hint.text = "TOQUE VOLTAR DE NOVO PARA SAIR"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		var inset := SafeArea.insets(self)
		hint.offset_top = -64.0 - inset.w   # acima da barra de gestos
		hint.offset_bottom = -24.0 - inset.w
		hint.add_theme_font_size_override("font_size", 20)
		hint.add_theme_color_override("font_outline_color", Color.BLACK)   # lê sobre o planeta
		hint.add_theme_constant_override("outline_size", 6)
		add_child(hint)
	hint.modulate.a = 1.0
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(EXIT_WINDOW_MSEC / 1000.0 - 0.4)
	_hint_tween.tween_property(hint, "modulate:a", 0.0, 0.4)


func _quit_game() -> void:
	get_tree().quit()


func _open_settings() -> void:
	get_node("Music").deepen()
	var panel := SettingsPanel.new()
	panel.name = "SettingsPanel"
	panel.closed.connect(func():
		panel.queue_free()
		get_node("Box/Footer/Settings").grab_focus())
	add_child(panel)


## Passo 107: o título equipado vai acima da linha do perfil e a moldura equipada vira a borda dela.
func _dress_profile(label: Label) -> void:
	Cosmetics.dress_frame(label, Cosmetics.frame_color())


func _profile_text() -> String:
	var title := Cosmetics.title_text()
	return ("" if title == "" else title.to_upper() + "\n") + "Nível %d  ·  Liga %s  ·  %d XP  ·  %d partidas\n%d moedas  ·  %d gemas  ·  conquistas %d/%d" % [Profile.level(), Leagues.name_of(int(Profile.data["rating"])), Profile.data["xp"], Profile.data["matches"], Profile.data["coins"], Profile.data.get("gems", 0), Profile.data["achievements"].size(), Achievements.LIST.size()]


func _add_dock(dock: Control, button_name: String, label: String, screen_class: GDScript) -> void:
	var button := _add_button(dock, button_name, label, func(): _open_screen(screen_class.new(), button_name), TOUCH_MIN, 14)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Passo 115: "MISSÕES (2)" quando há missão pronta para resgatar.
func _refresh_missions_badge() -> void:
	var n := DailyMissions.claimable()
	get_node("Box/Dock/Missions").text = "MISSÕES (%d)" % n if n > 0 else "MISSÕES"


## Passo 123: "PASSE DA TEMPORADA  ·  nível 3/20" e, com recompensa pronta, "PASSE  ·  2 recompensas!".
func _refresh_pass_label() -> void:
	var n := SeasonPass.claimable()
	get_node("Box/Pass").text = ("PASSE  ·  %d %s!" % [n, "recompensa" if n == 1 else "recompensas"]) if n > 0 \
			else "PASSE DA TEMPORADA  ·  nível %d/%d" % [SeasonPass.tiers_reached(), SeasonPass.TRACK.size()]


## Abre uma tela do menu por cima; o corpo do menu fica parado (sem foco nem cliques) até ela fechar.
func _open_screen(screen: MenuScreen, return_to: String) -> void:
	get_node("Music").deepen()
	var box: Control = get_node("Box")
	box.process_mode = Node.PROCESS_MODE_DISABLED
	screen.name = "Screen"
	screen.closed.connect(func():
		screen.queue_free()
		box.process_mode = Node.PROCESS_MODE_INHERIT
		get_node("Box/Profile").text = _profile_text()   # a loja pode ter gastado moedas ou trocado título e moldura
		_dress_profile(get_node("Box/Profile"))
		_refresh_missions_badge()   # resgatar na tela de missões muda o aviso
		_refresh_pass_label()
		_refresh_planet(Services.match_def.tutorial)   # a escolha de planeta pode ter mudado
		box.find_child(return_to, true, false).grab_focus())
	add_child(screen)


func _add_button(parent: Control, button_name: String, label: String, action: Callable, height := 56.0, font_size := 24) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.custom_minimum_size = Vector2(0.0, height)
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
