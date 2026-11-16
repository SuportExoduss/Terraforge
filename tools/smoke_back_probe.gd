extends Node
## Ajudante do smoke_back: conta cada ui_cancel que chega como entrada não tratada.
signal hit


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hit.emit()
