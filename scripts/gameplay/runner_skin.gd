class_name RunnerSkin
extends Node
## Troca o personagem do corredor pelo da civilização dele (DD-177): o Velho Oeste fica com o Pistoleiro da cena;
## a Floresta Encantada ganha o Guardião Élfico (G01 do Tripo Smart Mesh, rigado, com a corrida "Correr").
## Roda no _ready deste nó, que vem ANTES do de "Model" e do corredor (filhos ficam prontos em ordem, o pai por último):
## troca o conteúdo do "Model" por dentro, e o planet_runner.gd enquadra e anima o modelo novo sem saber da troca.
## ponytail: uma tabela kit -> modelo; as outras civilizações entram aqui quando o G01 delas existir.

const MODELS := {"floresta": "res://art/models/floresta/FlorestaG01_Guardiao.glb"}


func _ready() -> void:
	var runner := get_parent()
	var civilization := runner.get_node_or_null("Civilization") as Civilization
	var holder := runner.get_node_or_null("Model") as Node3D
	if civilization == null or holder == null or Services.themes == null:
		return
	var theme := Services.themes.theme_of(civilization.id)
	var path: String = MODELS.get(theme.procedural_kit if theme != null else "", "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene   # nunca preload de .glb na partida (carga lenta, Passo 87)
	if scene == null:
		return
	for child in holder.get_children():
		child.free()
	holder.add_child(scene.instantiate())
