extends SceneTree
## Teste de fumaça do Passo 129 (DD-168): ADAPTAÇÃO A TAMANHOS DE TELA. (1) a conta da área segura (SafeArea.from_rects) e o
## teto de 20%; (2) em vários tamanhos de tela (960x540, 960x720, 1170x540, 1260x540), com e sem um entalhe simulado, o menu e
## cada tela dele cabem: coluna inteira dentro da tela e da área segura, VOLTAR preso na base e acima da barra de gestos, todo
## botão com altura de dedo (>= 48 px); (3) o HUD (placas, botão II) e o minimapa ficam dentro da área segura e o clarão de dano
## e o analógico seguem cobrindo a tela inteira. Cada tela roda num SubViewport do tamanho testado (a janela do headless não muda).
## Uso: godot_console --headless --path . -s res://tools/smoke_screens.gd

const SafeArea := preload("res://scripts/core/safe_area.gd")
const TOUCH := 47.5
const NOTCH := Vector4(48.0, 0.0, 48.0, 24.0)   # esquerda, cima, direita, baixo (px do canvas)
const CASES := [
	[Vector2i(960, 540), Vector4.ZERO],
	[Vector2i(960, 540), NOTCH],
	[Vector2i(960, 720), Vector4.ZERO],
	[Vector2i(1170, 540), NOTCH],
	[Vector2i(1260, 540), Vector4.ZERO],
]
const DOCK := ["Dock/Profile", "Dock/Civilizations", "Dock/Shop", "Dock/Online", "Dock/Events", "Dock/Missions", "Planet", "Pass"]

var _failed := false


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	Profile.path = "user://profile_smoke_screens.json"   # perfil próprio, de quem já jogou
	Profile.data = Profile.defaults()
	Profile.data["matches"] = 1
	Profile.save()

	# 1. A conta pura (tela 2400x1080 vira um canvas 1200x540: 0,5 px de canvas por pixel real)
	var view := Vector2(1200.0, 540.0)
	var screen := Vector2(2400.0, 1080.0)
	_check(SafeArea.from_rects(Rect2(Vector2.ZERO, screen), screen, view) == Vector4.ZERO, "tela inteira segura = folga zero")
	_check(SafeArea.from_rects(Rect2(96.0, 0.0, 2208.0, 1032.0), screen, view) == NOTCH, "entalhe de 96 px dos lados e barra de 48 px embaixo = (48,0,48,24)")
	_check(SafeArea.from_rects(Rect2(0.0, 0.0, 0.0, 0.0), screen, view) == Vector4.ZERO, "área segura vazia (sistema sem resposta) = folga zero")
	_check(SafeArea.from_rects(Rect2(1000.0, 0.0, 100.0, 100.0), screen, view).x == view.x * SafeArea.MAX_SHARE, "uma folga absurda é cortada em 20% da tela")
	_check(SafeArea.insets(root) == Vector4.ZERO, "no PC (sem celular) a folga é zero")

	var theme: Theme = load("res://scripts/ui/ui_theme.gd").build()
	for case in CASES:
		var size: Vector2i = case[0]
		var inset: Vector4 = case[1]
		SafeArea.test_insets = inset
		var tag := "%dx%d inset=%s" % [size.x, size.y, inset]
		var vp := SubViewport.new()
		vp.size = size
		vp.handle_input_locally = false
		root.add_child(vp)
		await _menu_case(vp, theme, size, inset, tag)
		await _hud_case(vp, theme, size, inset, tag)
		vp.queue_free()
		await _frames(2)
	SafeArea.test_insets = Vector4.ZERO
	if not _failed:
		print("OK")
		quit(0)


## Cabe dentro da tela e da área segura (tolerância de meio pixel).
func _inside(rect: Rect2, size: Vector2i, inset: Vector4) -> bool:
	return rect.position.x >= inset.x - 0.5 and rect.position.y >= inset.y - 0.5 \
			and rect.end.x <= size.x - inset.z + 0.5 and rect.end.y <= size.y - inset.w + 0.5


func _fingers(node: Node, tag: String) -> void:
	for control in node.find_children("*", "BaseButton", true, false):
		var button := control as BaseButton
		if button.is_visible_in_tree():
			_check(button.size.y >= TOUCH, "%s: botão %s com altura de dedo (%.0f)" % [tag, button.name, button.size.y])


func _menu_case(vp: SubViewport, theme: Theme, size: Vector2i, inset: Vector4, tag: String) -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.theme = theme
	vp.add_child(menu)
	await _frames(4)
	var box: Control = menu.get_node("Box")
	_check(_inside(box.get_global_rect(), size, inset), "%s: a coluna do menu cabe na área segura (%s)" % [tag, box.get_global_rect()])
	_check(box.get_global_rect().position.x >= inset.x + 40.0, "%s: a coluna do menu respeita a margem esquerda" % tag)
	_fingers(menu, tag + " menu")
	var footer: Control = menu.get_node("Box/Footer")
	_check(footer.get_node("Settings").size.x > footer.get_node("Quit").size.x and footer.get_node("Quit").size.x >= 100.0, "%s: CONFIGURAÇÕES e SAIR lado a lado, SAIR com largura de dedo" % tag)

	for path in DOCK:
		box.get_node(path).pressed.emit()
		await _frames(3)
		var screen: Control = menu.get_node_or_null("Screen")
		_check(screen != null, "%s: %s abre a tela" % [tag, path])
		var back: Button = screen.get("back")
		_check(back.size.y >= 52.0 - 0.5, "%s %s: VOLTAR com altura de dedo (%.0f)" % [tag, path, back.size.y])
		_check(_inside(back.get_global_rect(), size, inset), "%s %s: VOLTAR dentro da tela e acima da barra de gestos (%s)" % [tag, path, back.get_global_rect()])
		_check(absf(back.get_global_rect().get_center().x - size.x * 0.5) < 1.0, "%s %s: VOLTAR centralizado" % [tag, path])
		var scroll: Control = screen.get_node("Scroll")
		_check(_inside(scroll.get_global_rect(), size, inset), "%s %s: a rolagem fica na área segura" % [tag, path])
		_check(scroll.get_global_rect().end.y <= back.get_global_rect().position.y, "%s %s: a rolagem termina acima do VOLTAR (%s / %s)" % [tag, path, scroll.get_global_rect(), back.get_global_rect()])
		var card: Control = screen.find_child("Card", true, false)
		_check(card.get_global_rect().size.x <= size.x - inset.x - inset.z + 0.5, "%s %s: o cartão cabe na largura (%.0f)" % [tag, path, card.size.x])
		_fingers(screen, "%s %s" % [tag, path])
		back.pressed.emit()
		await _frames(3)
		_check(menu.get_node_or_null("Screen") == null, "%s %s: VOLTAR fecha a tela" % [tag, path])

	# Configurações (o mesmo VOLTAR preso)
	footer.get_node("Settings").pressed.emit()
	await _frames(3)
	var settings: Control = menu.get_node_or_null("SettingsPanel")
	_check(settings != null, "%s: CONFIGURAÇÕES abre o painel" % tag)
	var settings_back: Button = settings.find_child("Back", true, false)
	_check(settings_back.size.y >= 51.5 and _inside(settings_back.get_global_rect(), size, inset), "%s: VOLTAR das configurações preso na base (%s)" % [tag, settings_back.get_global_rect()])
	_fingers(settings, tag + " configurações")
	settings_back.pressed.emit()
	await _frames(3)
	_check(menu.get_node_or_null("SettingsPanel") == null, "%s: VOLTAR fecha as configurações" % tag)
	menu.queue_free()
	await _frames(2)


func _hud_case(vp: SubViewport, theme: Theme, size: Vector2i, inset: Vector4, tag: String) -> void:
	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	vp.add_child(hud)
	var mini: Control = load("res://scenes/minimap.tscn").instantiate()   # na partida o minimapa é filho do HUD
	hud.add_child(mini)
	await _frames(4)
	var whole := Rect2(Vector2.ZERO, Vector2(size))
	var card: Control = hud.get_node("Root/ScoreCard")
	_check(card.get_global_rect().position.x >= inset.x and card.get_global_rect().position.y >= inset.y, "%s HUD: o cartão do domínio fora do entalhe (%s)" % [tag, card.get_global_rect()])
	var pause: Button = hud.get_node("Root/PauseButton")
	_check(_inside(pause.get_global_rect(), size, inset), "%s HUD: o botão II dentro da área segura (%s)" % [tag, pause.get_global_rect()])
	_check(pause.size.x >= 48.0 and pause.size.y >= 48.0, "%s HUD: o botão II com tamanho de dedo" % tag)
	var mini_rect := mini.get_global_rect()
	_check(_inside(mini_rect, size, inset), "%s HUD: o minimapa dentro da área segura (%s)" % [tag, mini_rect])
	_check(not pause.get_global_rect().intersects(mini_rect), "%s HUD: o botão II não cobre o minimapa" % tag)
	var bonus: Control = hud.get_node("Root/Bonuses")
	_check(bonus.get_global_rect().end.x <= size.x - inset.z + 0.5, "%s HUD: a coluna de bônus fora do entalhe direito" % tag)
	var flash: Control = hud.get_node("Root/DamageFlash")
	var joystick: Control = hud.get_node("Root/Joystick")
	_check(flash.get_global_rect() == whole, "%s HUD: o clarão de dano cobre a tela inteira (%s)" % [tag, flash.get_global_rect()])
	_check(joystick.get_global_rect() == whole, "%s HUD: o analógico desenha em coordenadas da tela inteira (%s)" % [tag, joystick.get_global_rect()])
	hud.queue_free()
	await _frames(2)
