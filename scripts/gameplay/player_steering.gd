class_name PlayerSteering
extends Node
## O motorista humano. Direção por PONTEIRO (toque no celular vira mouse via emulação; mouse no PC):
## tocar cria um analógico flutuante sob o dedo; arrastar para os lados curva a corrida.
## Teclado (A/D, setas) vale como alternativa. Posições em pixels do viewport virtual (960x540, celular deitado).

@export var joystick_radius_pixels: float = 60.0
@export var joystick_dead_zone: float = 0.08

var _tracking := false
var _origin := Vector2.ZERO
var _was_pressed := false


func _exit_tree() -> void:
	_stop_tracking()


func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var position := get_viewport().get_mouse_position()
	var just_pressed := pressed and not _was_pressed
	_was_pressed = pressed

	if not _tracking:
		if just_pressed and not TouchSteering.is_ui_pointer_held:
			_tracking = true
			_origin = position
			TouchSteering.begin(_origin)
		return

	if not pressed or TouchSteering.is_ui_pointer_held:
		_stop_tracking()
		return

	# Só o eixo horizontal vira direção: a corrida é automática, o jogador só controla a curva.
	var clamped := (position - _origin).limit_length(joystick_radius_pixels)
	var steer := clamped.x / joystick_radius_pixels
	TouchSteering.set_value(steer if absf(steer) >= joystick_dead_zone else 0.0, clamped)


func get_steer() -> float:
	var raw := TouchSteering.value if _tracking and absf(TouchSteering.value) > 0.001 else Settings.steer_axis()
	return clampf(raw * Settings.turn_gain(), -1.0, 1.0)   # Passo 55: sensibilidade do giro (configurações)


func _stop_tracking() -> void:
	if _tracking:
		_tracking = false
		TouchSteering.clear()
