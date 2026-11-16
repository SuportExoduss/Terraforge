extends Node
## Passo 128 (DD-167): o botão VOLTAR do Android (aviso WM_GO_BACK_REQUEST, ou a tecla BACK em alguns aparelhos) vira a
## ação "ui_cancel" — a mesma do ESC —, e cada tela decide o que "voltar" significa (fechar, pausar, avisar, ir ao menu).
## O projeto desliga `quit_on_go_back`: sem isto o voltar fecharia o jogo em qualquer tela.
## ponytail: uma trava de 250 ms impede o mesmo toque de contar duas vezes quando o aparelho manda aviso E tecla.

const GUARD_MSEC := 250

var _last := -GUARD_MSEC


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # com a partida pausada o voltar precisa chegar na pausa


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_BACK:
		get_viewport().set_input_as_handled()
		go_back()


func go_back() -> void:
	var now := Time.get_ticks_msec()
	if now - _last < GUARD_MSEC:
		return
	_last = now
	for pressed in [true, false]:
		var action := InputEventAction.new()
		action.action = "ui_cancel"
		action.pressed = pressed
		Input.parse_input_event(action)
