class_name CivilizationCatalog
extends RefCounted
## As civilizações do jogo para o menu (GDMD Adendo 03, "temas aprovados — primeira leva"): nome, cor do solo e se já
## dá para jogar com ela. "Jogável" = a ficha de bioma tem piso de arte OU um kit procedural (DD-150): o Velho Oeste tem arte,
## as outras 5 têm kit. Quando uma ficha ganhar arte nos slots, ela vence o kit sozinha. A escolha fica no Profile ("civilization").
## ponytail: a ordem dos nomes é a ordem do GDMD (civilização 1 = Velho Oeste, 2 = Alien...); sem descrição nem retrato.

const NAMES := ["Velho Oeste", "Alien", "Floresta Encantada", "Skate City", "Piratas", "Reino do Gelo"]
const THEME_PATH := "res://art/themes/theme_civ%d.tres"


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
