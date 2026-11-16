extends RefCounted
## Passo 129 (DD-168): a FOLGA do entalhe (câmera) e das barras do sistema, em pixels do canvas (o 960x540 virtual mais a
## faixa extra das telas compridas): Vector4(esquerda, cima, direita, baixo). A interface ancora nas bordas da tela
## inteira; quem tem texto ou botão nas bordas soma esta folga e nada fica atrás do entalhe ou da barra de gestos.
## No PC é sempre zero: só o celular tem área segura de verdade (no desktop o sistema devolve a área útil menos a barra de tarefas).
## ponytail: lido quando a tela monta (e quando a janela muda de tamanho); girar o celular de ponta-cabeça sem mudar o tamanho não reajusta.

const MAX_SHARE := 0.2   # nenhuma folga passa de 20% da tela: um valor absurdo do sistema não pode comer a interface

static var test_insets := Vector4.ZERO   # só os testes: simula um entalhe sem celular


static func insets(node: Node) -> Vector4:
	if test_insets != Vector4.ZERO:
		return test_insets
	var window := node.get_window()
	if window == null or not OS.has_feature("mobile"):
		return Vector4.ZERO
	var view: Vector2 = node.get_viewport().get_visible_rect().size
	return from_rects(DisplayServer.get_display_safe_area(), Vector2(DisplayServer.screen_get_size()), view)


## A conta pura (testada sem celular): `safe` e `screen` em pixels reais, `view` em pixels do canvas.
static func from_rects(safe: Rect2, screen: Vector2, view: Vector2) -> Vector4:
	if safe.size.x <= 0.0 or safe.size.y <= 0.0 or screen.x <= 0.0 or screen.y <= 0.0 or view.x <= 0.0 or view.y <= 0.0:
		return Vector4.ZERO
	var scale := view / screen   # pixels do canvas por pixel real
	var cap := view * MAX_SHARE
	return Vector4(
		clampf(safe.position.x * scale.x, 0.0, cap.x),
		clampf(safe.position.y * scale.y, 0.0, cap.y),
		clampf((screen.x - safe.end.x) * scale.x, 0.0, cap.x),
		clampf((screen.y - safe.end.y) * scale.y, 0.0, cap.y))
