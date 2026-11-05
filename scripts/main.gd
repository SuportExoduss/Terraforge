extends Node3D
## Inicialização de desenvolvimento: dispara o GO! sozinho até o MatchSetup (cerimônia) ser portado.

@export var autostart_delay: float = 0.5


func _ready() -> void:
	await get_tree().create_timer(autostart_delay).timeout
	EventBus.match_started.emit()
