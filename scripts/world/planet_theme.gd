class_name PlanetTheme
extends Resource
## A ficha de bioma de uma civilização (DD-114/DD-115). Quem governa a aparência do império é a ficha,
## não o código: adicionar uma civilização é adicionar uma ficha ao PlanetThemeRegistry.
## Etapa 4: piso (E00), cor do solo e Death Biome. Slots de ambiente (E01-E12) entram na etapa 5.
## Os arquivos de textura são CAMINHOS (não Texture2D): o piso original tem 4096 px e não deve
## ocupar memória em jogo — a ferramenta tools/build_ground_atlas.gd o reduz para o atlas.

@export var civilization_name := "Neutro"

@export_group("Piso E00 (material completo)")
@export_file var ground_texture_file := ""
@export_file var ground_normal_file := ""
@export_file var ground_ao_file := ""
## Correção de cor sobre o material (cinza 0,5 = neutro; o shader multiplica por 2).
@export var ground_tint := Color(0.5, 0.5, 0.5)
@export_range(0.0, 2.0) var ground_relief := 1.0
## Altura da camada de bioma que SOBE sobre a terra neutra (DD-121).
@export_range(0.0, 3.0) var ground_height := 0.6
@export_range(1.0, 64.0) var ground_tiling := 16.0

@export_group("Kit de Terreno (DD-116)")
## Cor chapada do solo: o que o mapa de posse pinta (e o que vale para civilização sem textura).
@export var soil_base := Color(0.55, 0.42, 0.28)

@export_group("Death Biome (DD-122)")
@export_file var dead_ground_texture_file := ""
@export_file var dead_ground_normal_file := ""
@export var dead_ground_tint := Color(0.4, 0.38, 0.36)
