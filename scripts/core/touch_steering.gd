class_name TouchSteering
extends RefCounted
## Canal de direção por toque (Core guarda só o dado; UI e Gameplay não se referenciam).

static var value := 0.0
static var is_active := false
static var is_ui_pointer_held := false
static var origin := Vector2.ZERO
static var knob_offset := Vector2.ZERO


static func begin(from: Vector2) -> void:
	is_active = true
	origin = from
	knob_offset = Vector2.ZERO
	value = 0.0


static func set_value(v: float, knob: Vector2) -> void:
	value = clampf(v, -1.0, 1.0)
	knob_offset = knob


static func set_ui_pointer_held(held: bool) -> void:
	is_ui_pointer_held = held
	if held:
		clear()


static func clear() -> void:
	value = 0.0
	is_active = false
	knob_offset = Vector2.ZERO
