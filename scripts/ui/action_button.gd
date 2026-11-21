class_name ActionButton
extends Button
## Passo 155 (DD-194): botão redondo de ação da partida (SPRINT e habilidade do bioma). Pronto = borda e brilho na cor da ação, com a letra e o
## nome embaixo; recarregando = apagado, os segundos no meio e um anel que enche até a carga voltar; ao ficar pronto dá um pulinho
## (só sem "reduzir movimento"). Só mostra: quem decide o uso é o SkillSystem; os testes seguem lendo `text` e `disabled`.
## ponytail: o anel é um draw_arc; vira textura quando houver arte de ícones.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var accent := Color.WHITE
var icon_text := "?"
var decimal := false   # true = recarga curta (sprint): mostra "2.3"; false = "8"
var left := 0.0    # segundos que faltam (0 = pronta)
var total := 1.0   # duração da recarga que começou agora
var _caption: Label
var _hint: Label   # Passo 157: selo com a tecla do atalho, fora do círculo (só PC)


func _init(color := Color.WHITE, caption := "", icon := "?", with_decimal := false) -> void:
	decimal = with_decimal
	focus_mode = Control.FOCUS_NONE   # o atalho é a tecla; ESPAÇO/ENTER não podem acionar por foco
	add_theme_font_size_override("font_size", 30)
	add_theme_color_override("font_disabled_color", UiTheme.INK_DIM)
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size", 11)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -20.0
	_caption.offset_bottom = -4.0
	add_child(_caption)
	set_look(color, caption, icon)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


## Passo 157: mostra a tecla do atalho num selo à esquerda do botão ("" esconde). `text` e `icon_text` não mudam.
func set_key_hint(key_text: String) -> void:
	if _hint == null:
		_hint = Label.new()
		_hint.name = "KeyHint"
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.add_theme_font_size_override("font_size", 14)
		_hint.add_theme_color_override("font_color", UiTheme.INK)
		var style := StyleBoxFlat.new()
		style.bg_color = UiTheme.GLASS
		style.border_color = UiTheme.LINE
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
		_hint.add_theme_stylebox_override("normal", style)
		_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
		_hint.offset_left = -6.0
		_hint.offset_right = -6.0
		add_child(_hint)
	_hint.text = key_text
	_hint.visible = key_text != ""


## Passo 156: o botão cresce e encolhe (Ajustes, tela); letra, nome e anel acompanham o diâmetro (76 px = 30 / 11 / 5).
func _fit() -> void:
	var d := minf(size.x, size.y)
	if d <= 0.0 or _caption == null:
		return
	add_theme_font_size_override("font_size", roundi(d * 0.4))
	_caption.add_theme_font_size_override("font_size", clampi(roundi(d * 0.145), 9, 22))
	_caption.offset_top = -d * 0.26
	_caption.offset_bottom = -d * 0.05
	queue_redraw()


## Cor, nome e letra da ação (a habilidade só sabe qual é quando a partida avisa a carga).
func set_look(color: Color, caption: String, icon: String) -> void:
	accent = color
	icon_text = icon
	_caption.text = caption
	_caption.add_theme_color_override("font_color", accent)
	add_theme_stylebox_override("normal", _style(accent.darkened(0.65), accent, 4, 10))
	add_theme_stylebox_override("hover", _style(accent.darkened(0.5), accent, 4, 12))
	add_theme_stylebox_override("pressed", _style(accent.darkened(0.3), accent.lightened(0.3), 4, 14))
	add_theme_stylebox_override("disabled", _style(UiTheme.GLASS, UiTheme.LINE, 3, 0))
	charge(left, total)


static func _style(bg: Color, border: Color, border_width: int, glow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(100)   # maior que a metade do botão (até 140 px): vira círculo
	style.anti_aliasing = true
	if glow > 0:
		style.shadow_color = Color(border.r, border.g, border.b, 0.45)
		style.shadow_size = glow
	return style


## `seconds_left` = quanto falta; `duration` = a recarga inteira (para o anel). Chamar toda vez que o relógio andar.
func charge(seconds_left: float, duration: float) -> void:
	var was_charging := left > 0.0
	left = maxf(seconds_left, 0.0)
	total = maxf(duration, 0.001)
	disabled = left > 0.0
	text = icon_text if left <= 0.0 else ("%.1f" % left if decimal else "%d" % ceili(left))
	_caption.visible = left <= 0.0   # recarregando, o número ocupa o botão
	queue_redraw()
	if was_charging and left <= 0.0:
		_pop()


## O quanto da recarga já passou (0 = acabou de usar, 1 = pronta).
func progress() -> float:
	return 1.0 if left <= 0.0 else clampf(1.0 - left / total, 0.0, 1.0)


func _draw() -> void:
	if left <= 0.0:
		return
	var center := size * 0.5
	var d := minf(size.x, size.y)
	var width := maxf(3.0, d * 0.066)
	var radius := d * 0.5 - width
	draw_arc(center, radius, 0.0, TAU, 48, Color(UiTheme.LINE, 0.5), width, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress(), 48, accent, width, true)


func _pop() -> void:
	if Settings.reduced_motion() or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
