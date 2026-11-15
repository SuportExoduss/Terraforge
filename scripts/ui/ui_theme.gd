extends RefCounted
## Tema visual do jogo (Passo 109, DD-149): UM Theme em código, aplicado na janela raiz — todo botão, rótulo, painel e barra do
## menu, lojas e HUD herdam a mesma cara. Mundo visual: ESPAÇO PROFUNDO (azul-marinho quase preto) + a FORJA (âmbar incandescente,
## só nas ações que importam: JOGAR, o item equipado, o foco do teclado) + um azul frio de vidro para o resto. Cor nunca é o único
## sinal: o estado do botão também muda a borda e o texto.
## Sem class_name de propósito (use `const UiTheme := preload("res://scripts/ui/ui_theme.gd")`): não exige reimportar o projeto.
## Botão principal: `button.theme_type_variation = "PrimaryButton"`. Painel: PanelContainer comum.

const SPACE := Color(0.03, 0.05, 0.12)         # fundo
const GLASS := Color(0.07, 0.10, 0.19, 0.94)   # botões e painéis
const GLASS_HI := Color(0.12, 0.17, 0.30, 0.97)
const LINE := Color(0.24, 0.34, 0.55)          # borda de repouso
const COOL := Color(0.45, 0.78, 1.0)           # borda ao passar o mouse
const FORGE := Color(1.0, 0.62, 0.18)          # âmbar da forja: ação principal e foco
const FORGE_HI := Color(1.0, 0.74, 0.34)
const INK := Color(0.93, 0.95, 1.0)            # texto
const INK_DIM := Color(0.60, 0.67, 0.80)       # texto secundário
const INK_OFF := Color(0.42, 0.47, 0.60)       # texto desligado
const COIN := Color(1.0, 0.82, 0.25)           # moedas
const GEM := Color(0.45, 0.95, 0.9)            # gemas

static var _cached: Theme = null


static func build() -> Theme:
	if _cached != null:
		return _cached
	var theme := Theme.new()

	# Rótulos
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.04, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)

	# Variações de rótulo (theme_type_variation): título com brilho de forja, texto apagado, moedas, gemas e cartão do perfil
	var bold := _font(0.45, 0.0)
	var logo := _font(0.7, 4.0)
	theme.add_type("TitleLabel")
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", logo)
	theme.set_color("font_color", "TitleLabel", Color.WHITE)
	theme.set_color("font_outline_color", "TitleLabel", Color(1.0, 0.5, 0.1, 0.32))
	theme.set_constant("outline_size", "TitleLabel", 10)
	theme.add_type("DimLabel")
	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", INK_DIM)
	theme.add_type("CoinLabel")
	theme.set_type_variation("CoinLabel", "Label")
	theme.set_color("font_color", "CoinLabel", COIN)
	theme.set_font("font", "CoinLabel", bold)
	theme.add_type("GemLabel")
	theme.set_type_variation("GemLabel", "Label")
	theme.set_color("font_color", "GemLabel", GEM)
	theme.set_font("font", "GemLabel", bold)
	theme.add_type("ProfileLabel")
	theme.set_type_variation("ProfileLabel", "Label")
	theme.set_stylebox("normal", "ProfileLabel", _box(Color(0.05, 0.08, 0.16, 0.9), LINE, 2, 14, 10))

	# Botão comum: vidro azul-escuro com borda fina
	theme.set_font("font", "Button", bold)
	theme.set_stylebox("normal", "Button", _box(GLASS, LINE))
	theme.set_stylebox("hover", "Button", _box(GLASS_HI, COOL))
	theme.set_stylebox("pressed", "Button", _box(Color(0.04, 0.06, 0.12, 0.98), FORGE))
	theme.set_stylebox("disabled", "Button", _box(Color(0.06, 0.08, 0.14, 0.75), Color(0.16, 0.21, 0.33)))
	theme.set_stylebox("focus", "Button", _ring(FORGE))
	_ink(theme, "Button", INK, Color.WHITE, FORGE_HI, INK_OFF)

	# Botão principal (JOGAR, abas escolhidas): âmbar cheio com brilho
	theme.add_type("PrimaryButton")
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_font("font", "PrimaryButton", _font(0.7, 2.0))
	theme.set_stylebox("normal", "PrimaryButton", _glow(FORGE, FORGE_HI))
	theme.set_stylebox("hover", "PrimaryButton", _glow(FORGE_HI, Color.WHITE))
	theme.set_stylebox("pressed", "PrimaryButton", _glow(Color(0.86, 0.46, 0.1), FORGE))
	theme.set_stylebox("disabled", "PrimaryButton", _box(Color(0.25, 0.17, 0.08, 0.7), Color(0.4, 0.28, 0.12)))
	theme.set_stylebox("focus", "PrimaryButton", _ring(Color.WHITE))
	_ink(theme, "PrimaryButton", Color(0.14, 0.07, 0.02), Color(0.14, 0.07, 0.02), Color(0.14, 0.07, 0.02), INK_OFF)

	# Botão discreto (CONFIGURAÇÕES, SAIR): sem fundo até passar o mouse, para não competir com JOGAR
	theme.add_type("GhostButton")
	theme.set_type_variation("GhostButton", "Button")
	theme.set_stylebox("normal", "GhostButton", _box(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)))
	theme.set_stylebox("hover", "GhostButton", _box(Color(1, 1, 1, 0.07), LINE))
	theme.set_stylebox("pressed", "GhostButton", _box(Color(1, 1, 1, 0.04), FORGE))
	_ink(theme, "GhostButton", INK_DIM, Color.WHITE, FORGE_HI, INK_OFF)

	# Painel
	theme.set_stylebox("panel", "PanelContainer", _box(GLASS, LINE, 2, 18, 16))
	theme.set_stylebox("panel", "Panel", _box(GLASS, LINE, 2, 18, 16))

	# Barra de progresso (XP do perfil): trilho escuro, preenchimento âmbar
	theme.set_stylebox("background", "ProgressBar", _flat(Color(0.14, 0.2, 0.34), 7, 0))
	theme.set_stylebox("fill", "ProgressBar", _flat(FORGE, 7, 0))

	# Barra de rolagem e controles deslizantes (configurações)
	theme.set_stylebox("scroll", "VScrollBar", _flat(Color(1, 1, 1, 0.05), 6, 0))
	theme.set_stylebox("grabber", "VScrollBar", _flat(Color(0.45, 0.6, 0.9, 0.55), 6, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _flat(COOL, 6, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _flat(FORGE, 6, 0))
	var track := _flat(Color(0.14, 0.2, 0.34), 4, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	var fill := _flat(FORGE, 4, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)

	_cached = theme
	return theme


## Tema na janela raiz: todo controle do jogo herda. Chamado uma vez pelo Services (autoload).
static func apply(tree: SceneTree) -> void:
	tree.root.theme = build()


## Fundo das telas: azul-marinho profundo que clareia para baixo (gradiente), em vez de uma cor chapada.
static func backdrop() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.03, 0.09))
	gradient.set_color(1, Color(0.06, 0.09, 0.2))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## Sombra lateral do menu: navy forte na esquerda (onde ficam título e botões) que some antes do planeta.
static func left_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.62])
	gradient.colors = PackedColorArray([Color(0.02, 0.03, 0.09, 0.94), Color(0.02, 0.03, 0.09, 0.8), Color(0.02, 0.03, 0.09, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var rect := TextureRect.new()
	rect.name = "Shade"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## Cartão de item (loja): vidro com borda na cor da raridade; o EQUIPADO ganha o âmbar da forja.
static func card(rarity: Color, equipped: bool) -> StyleBoxFlat:
	var style := _box(Color(0.08, 0.11, 0.2, 0.96) if not equipped else Color(0.2, 0.13, 0.07, 0.96), FORGE if equipped else rarity.darkened(0.25), 3 if equipped else 2, 14, 10)
	return style


## Fonte padrão engrossada (`embolden`) e com espaço extra entre letras (`spacing`).
static func _font(embolden: float, spacing: float) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = embolden
	font.spacing_glyph = int(spacing)
	return font


static func _ink(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color, disabled: Color) -> void:
	theme.set_color("font_color", type, normal)
	theme.set_color("font_hover_color", type, hover)
	theme.set_color("font_focus_color", type, hover)
	theme.set_color("font_pressed_color", type, pressed)
	theme.set_color("font_hover_pressed_color", type, pressed)
	theme.set_color("font_disabled_color", type, disabled)


static func _flat(bg: Color, radius: int, border_width: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.border_color = border
	return style


static func _box(bg: Color, border: Color, border_width := 2, radius := 14, margin := 12) -> StyleBoxFlat:
	var style := _flat(bg, radius, border_width, border)
	style.content_margin_left = margin + 2
	style.content_margin_right = margin + 2
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	style.anti_aliasing = true
	return style


static func _glow(bg: Color, border: Color) -> StyleBoxFlat:
	var style := _box(bg, border, 2, 14, 12)
	style.shadow_color = Color(1.0, 0.5, 0.1, 0.38)
	style.shadow_size = 12
	return style


## Anel de foco (teclado/controle): só a borda, sem preencher.
static func _ring(color: Color) -> StyleBoxFlat:
	var style := _flat(Color.TRANSPARENT, 14, 3, color)
	style.draw_center = false
	style.expand_margin_left = 2
	style.expand_margin_right = 2
	style.expand_margin_top = 2
	style.expand_margin_bottom = 2
	return style
