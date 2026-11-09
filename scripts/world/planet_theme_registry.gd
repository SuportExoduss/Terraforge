class_name PlanetThemeRegistry
extends Node
## O catálogo de fichas (PLS, DD-114): elemento 0 = civilização 1, elemento 1 = civilização 2...
## Quem precisa de cor/solo/atlas pergunta aqui via Services.themes.

@export var civilization_themes: Array[PlanetTheme] = []
@export var atlas: GroundAtlas


func _enter_tree() -> void:
	Services.themes = self   # _enter_tree: antes do _ready de qualquer irmão que vá consultá-lo
	apply_choice(CivilizationCatalog.chosen())


func _exit_tree() -> void:
	if Services.themes == self:
		Services.themes = null


## A ficha da civilização (null se ela não tiver uma).
func theme_of(civilization_id: int) -> PlanetTheme:
	var index := civilization_id - 1
	if index < 0 or index >= civilization_themes.size():
		return null
	return civilization_themes[index]


## A civilização escolhida no menu (Passo 41) assume o lugar da 1 (a do jogador): as duas trocam de ficha e de fatia do
## atlas. A troca é numa cópia do atlas, para o recurso em cache continuar intacto (chamar de novo não desfaz nada).
## ponytail: o solo só sai certo se a civilização escolhida tem piso no atlas (é a regra de "jogável" do catálogo).
func apply_choice(chosen: int) -> void:
	var index := chosen - 1
	if index <= 0 or index >= civilization_themes.size():
		return
	var first := civilization_themes[0]
	civilization_themes[0] = civilization_themes[index]
	civilization_themes[index] = first
	if atlas == null:
		return
	atlas = atlas.duplicate()
	atlas.slice_of = _swapped(atlas.slice_of, index)
	atlas.dead_slice_of = _swapped(atlas.dead_slice_of, index)


# Cópia com as posições 0 e `index` trocadas (array empacotado é passado por referência: nunca mexer no original).
static func _swapped(slices: PackedInt32Array, index: int) -> PackedInt32Array:
	var out := slices.duplicate()
	if index < out.size():
		out[0] = slices[index]
		out[index] = slices[0]
	return out
