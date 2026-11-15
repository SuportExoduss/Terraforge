class_name PlanetTheme
extends Resource
## A ficha de bioma de uma civilização (DD-114/DD-115). Quem governa a aparência do império é a ficha,
## não o código: adicionar uma civilização é adicionar uma ficha ao PlanetThemeRegistry.
## Piso (E00), cor do solo, Death Biome, Biome DNA (DD-118) e os 12 slots de ambiente (E01-E12, DD-120).
## Os arquivos de textura são CAMINHOS (não Texture2D): o piso original tem 4096 px e não deve
## ocupar memória em jogo — a ferramenta tools/build_ground_atlas.gd o reduz para o atlas.

const BiomeKit := preload("res://scripts/world/biome_kit.gd")

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

@export_group("Kit procedural (DD-150)")
## Nome do kit de props desenhado em código (scripts/world/biome_kit.gd): "alien", "floresta", "skate", "piratas" ou "gelo".
## Preenche os slots E01-E12 que NÃO têm modelo de arte (o modelo de arte vence, slot a slot). Vazio = sem kit.
@export var procedural_kit := ""

@export_group("Death Biome (DD-122)")
@export_file var dead_ground_texture_file := ""
@export_file var dead_ground_normal_file := ""
@export var dead_ground_tint := Color(0.4, 0.38, 0.36)

@export_group("Biome DNA (DD-118)")
## Fração dos slots de vegetação / rocha que este bioma realmente revela (o resto fica vazio).
@export_range(0.0, 1.0) var vegetation_density := 0.3
@export_range(0.0, 1.0) var rock_density := 0.5

# Slot vazio = nada é revelado ali (DD-110). Ordem fixa: o índice é o número do slot menos 1.
@export_group("Slots de ambiente E01-E12 (DD-120)")
@export var e01_vegetacao_alta: PackedScene
@export var e02_vegetacao_media: PackedScene
@export var e03_vegetacao_baixa: PackedScene
@export var e04_rocha_grande: PackedScene
@export var e05_rocha_pequena: PackedScene
@export var e06_estrutura_pequena: PackedScene
@export var e07_estrutura_media: PackedScene
@export var e08_estrutura_grande: PackedScene
@export var e09_decor_natural: PackedScene
@export var e10_decor_artificial: PackedScene
@export var e11_container: PackedScene
@export var e12_landmark: PackedScene

# Gêmeos mortos: slot vazio aqui = a versão viva escurecida (regra do vazio, DD-122).
@export_group("Death Biome E01m-E12m (DD-122)")
@export var e01m_vegetacao_alta: PackedScene
@export var e02m_vegetacao_media: PackedScene
@export var e03m_vegetacao_baixa: PackedScene
@export var e04m_rocha_grande: PackedScene
@export var e05m_rocha_pequena: PackedScene
@export var e06m_estrutura_pequena: PackedScene
@export var e07m_estrutura_media: PackedScene
@export var e08m_estrutura_grande: PackedScene
@export var e09m_decor_natural: PackedScene
@export var e10m_decor_artificial: PackedScene
@export var e11m_container: PackedScene
@export var e12m_landmark: PackedScene

const SLOT_COUNT := 12
const _SLOT_PROPS: Array[StringName] = [&"e01_vegetacao_alta", &"e02_vegetacao_media", &"e03_vegetacao_baixa",
		&"e04_rocha_grande", &"e05_rocha_pequena", &"e06_estrutura_pequena", &"e07_estrutura_media",
		&"e08_estrutura_grande", &"e09_decor_natural", &"e10_decor_artificial", &"e11_container", &"e12_landmark"]


## Modelo do slot `index` (0 = E01 ... 11 = E12), vivo ou morto. Pode ser null (slot vazio).
## Sem modelo de arte no slot vivo, vale o kit procedural da ficha (DD-150); o morto sem arte fica null (o sistema escurece o vivo).
func slot_model(index: int, dead: bool) -> PackedScene:
	var prop := String(_SLOT_PROPS[index])
	var art := get(prop.insert(3, "m") if dead else prop) as PackedScene   # "e01_x" -> "e01m_x"
	if art == null and not dead and procedural_kit != "":
		return BiomeKit.scene(procedural_kit, index)
	return art


## Biome DNA: densidade de revelação da categoria (vegetação E01-E03, rocha E04-E05, landmark sempre).
func density_of(index: int) -> float:
	if index <= 2:
		return vegetation_density
	if index <= 4:
		return rock_density
	return 1.0 if index == 11 else 0.5
