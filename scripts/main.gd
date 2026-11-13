extends Node3D
## Abertura (DD-096): o GO! sai quando TODAS as naves pousaram.
## ponytail: sem o MatchSetup (spawns sorteados longe dos polos) — entra no 6b; até lá a cena fixa as bases.

var _landed := {}
var _started := false


func _ready() -> void:
	EventBus.base_relocated.connect(_on_base_landed)


func _on_base_landed(owner_id: int, _position: Vector3) -> void:
	if _started:
		return
	_landed[owner_id] = true
	if _landed.size() >= get_tree().get_nodes_in_group("home_base").size():
		_started = true
		EventBus.match_started.emit()
		GameLog.say("[World] GO! Todas as naves pousaram — partida iniciada.")
