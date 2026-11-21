class_name CivilizationCatalog
extends RefCounted
## As civilizações do jogo para o menu (GDMD Adendo 03, "temas aprovados — primeira leva"): nome, cor do solo e se já
## dá para jogar com ela. "Jogável" = a ficha de bioma tem piso de arte OU um kit procedural (DD-150): o Velho Oeste tem arte,
## as outras 5 têm kit. Quando uma ficha ganhar arte nos slots, ela vence o kit sozinha. A escolha fica no Profile ("civilization").
## ponytail: a ordem dos nomes é a ordem do GDMD (civilização 1 = Velho Oeste, 2 = Alien...); sem descrição nem retrato.

const NAMES := ["Velho Oeste", "Alien", "Floresta Encantada", "Skate City", "Piratas", "Reino do Gelo"]
const THEME_PATH := "res://art/themes/theme_civ%d.tres"
## DD-183 (Passo 147): a habilidade especial de cada bioma, na mesma ordem de NAMES. "icon" = a letra no botão da HUD; "color" (Passo 155, DD-194) = a cor do botão.
const ABILITIES := [
	{"id": "lasso", "name": "Laço", "icon": "L", "color": Color(0.95, 0.72, 0.30), "text": "Prende o rival mais próximo: ele anda à metade da velocidade por 3 s."},
	{"id": "emp", "name": "Pulso EMP", "icon": "P", "color": Color(0.70, 0.50, 1.0), "text": "Os rivais por perto andam a 60% da velocidade por 2,5 s."},
	{"id": "heal", "name": "Cura da Floresta", "icon": "+", "color": Color(0.40, 0.90, 0.50), "text": "Recupera 1 coração de vida."},
	{"id": "trick", "name": "Manobra", "icon": "M", "color": Color(1.0, 0.45, 0.75), "text": "3 s de curva mais fechada: fecha circuito apertado."},
	{"id": "cannon", "name": "Canhonada", "icon": "C", "color": Color(1.0, 0.45, 0.25), "text": "Onda que empurra para longe os rivais por perto."},
	{"id": "frost", "name": "Armadura de Gelo", "icon": "A", "color": Color(0.65, 0.92, 1.0), "text": "2,5 s de escudo: nada tira vida (o rastro cortado ainda vale)."},
]


static func count() -> int:
	return NAMES.size()


static func theme_of(id: int) -> PlanetTheme:
	return load(THEME_PATH % id) as PlanetTheme


static func is_playable(id: int) -> bool:
	if id < 1 or id > count():
		return false
	var theme := theme_of(id)
	return theme != null and (theme.ground_texture_file != "" or theme.procedural_kit != "")   # piso de arte OU kit procedural (DD-150)


static func soil_color(id: int) -> Color:
	var theme := theme_of(id)
	return theme.soil_base if theme != null else Color.GRAY


## A habilidade do bioma `biome_id` (1..6).
static func ability_of(biome_id: int) -> Dictionary:
	return ABILITIES[clampi(biome_id, 1, count()) - 1]


## A habilidade pelo id ("lasso", "emp"...); vazio se não existir.
static func ability_named(ability_id: String) -> Dictionary:
	for ability: Dictionary in ABILITIES:
		if ability["id"] == ability_id:
			return ability
	return {}


## O bioma (1..6) que a civilização `civ_id` usa NA PARTIDA: a ficha dela no catálogo (a escolhida do jogador ocupa o espaço 1, ver
## PlanetThemeRegistry.apply_choice; os bots ficam com os outros biomas em rodízio).
static func biome_of(civ_id: int) -> int:
	var services: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Services")   # sem citar o autoload: os smokes -s compilam esta classe antes dele
	var theme: PlanetTheme = services.themes.theme_of(civ_id) if services != null and services.themes != null else null
	for id in range(1, count() + 1):
		if theme != null and theme.resource_path == THEME_PATH % id:
			return id
	return (civ_id - 1) % count() + 1


## A civilização que o jogador escolheu (volta à 1 se a escolhida não for jogável).
static func chosen() -> int:
	var id := clampi(int(Profile.data.get("civilization", 1)), 1, count())
	return id if is_playable(id) else 1


## Grava a escolha; recusa civilização que ainda não é jogável.
static func choose(id: int) -> bool:
	if id < 1 or id > count() or not is_playable(id):
		return false
	Profile.data["civilization"] = id
	Profile.save()
	return true
