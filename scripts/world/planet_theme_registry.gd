class_name PlanetThemeRegistry
extends Node
## O catálogo de fichas (PLS, DD-114): elemento 0 = civilização 1, elemento 1 = civilização 2...
## Quem precisa de cor/solo/atlas pergunta aqui via Services.themes.

@export var civilization_themes: Array[PlanetTheme] = []
@export var atlas: GroundAtlas


func _enter_tree() -> void:
	Services.themes = self   # _enter_tree: antes do _ready de qualquer irmão que vá consultá-lo


func _exit_tree() -> void:
	if Services.themes == self:
		Services.themes = null


## A ficha da civilização (null se ela não tiver uma).
func theme_of(civilization_id: int) -> PlanetTheme:
	var index := civilization_id - 1
	if index < 0 or index >= civilization_themes.size():
		return null
	return civilization_themes[index]
