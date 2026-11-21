extends RefCounted
## Passo 156 (DD-195): tamanho dos botões de toque da partida para QUALQUER tela. Parte do tamanho-base da HUD, aplica a escolha do
## jogador (Ajustes, 60% a 140%) e, em aparelho de toque, corrige pelo tamanho FÍSICO: celular de 6" e tablet de 10" têm a mesma
## HUD em unidades, mas o dedo é o mesmo, então o botão cresce onde a tela é "densa" e encolhe onde é grande. Nunca passa de uma fatia
## da tela (altura e largura), para não cobrir o jogo nem bater no minimapa e no bônus.
## Uso (sem class_name, preload): `const ControlLayout := preload("res://scripts/ui/control_layout.gd")`.

const MIN_SIZE := 44.0       # abaixo disso o dedo erra
const FINGER_INCH := 0.42    # ~10,7 mm: o alvo confortável de um polegar
const AUTO_MIN := 0.85
const AUTO_MAX := 1.4
const MAX_HEIGHT_SHARE := 0.24   # o botão ocupa no máximo 24% da altura...
const MAX_WIDTH_SHARE := 0.16    # ...e 16% da largura


## `base` = tamanho-base (unidades da HUD); `user_scale` = Settings.button_scale(); `view` = tamanho da HUD em unidades;
## `px_per_unit` = pixels reais por unidade (a escala do canvas_items); `dpi` = pontos por polegada da tela; `touch` = tela de toque.
static func action_size(base: float, user_scale: float, view: Vector2, px_per_unit: float, dpi: float, touch: bool) -> float:
	var auto := 1.0
	if touch and dpi > 0.0 and px_per_unit > 0.0:
		auto = clampf(FINGER_INCH * dpi / (base * px_per_unit), AUTO_MIN, AUTO_MAX)
	var cap := maxf(MIN_SIZE, minf(view.y * MAX_HEIGHT_SHARE, view.x * MAX_WIDTH_SHARE))
	return clampf(base * user_scale * auto, MIN_SIZE, cap)
