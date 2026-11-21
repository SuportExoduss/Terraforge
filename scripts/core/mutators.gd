extends RefCounted
## Mutador do dia (Passo 154, DD-193): todo dia as partidas ganham UMA regra diferente, igual para todos os jogadores naquele dia
## (rotação pelo número do dia, como os mapas do Brawl Stars): variedade que renova o jogo sem servidor e sem conteúdo novo.
## Só mexe em recarga, duração e frequência de meteoros, nunca em moeda, troféu ou prêmio (sem pay-to-win, DD-144). O treino não tem.
## Quem liga é o menu (`Services.mutator = Mutators.today_id()`); sem isso (testes, servidor) a partida é clássica.
## Uso (sem class_name, preload): `const Mutators := preload("res://scripts/core/mutators.gd")`.

const DailyMissions := preload("res://scripts/core/daily_missions.gd")

const CATALOG := [
	{"id": "turbo", "name": "TUDO TURBO", "blurb": "Sprint e habilidade recarregam na metade do tempo"},
	{"id": "chuva", "name": "CHUVA DE METEOROS", "blurb": "Os meteoros caem 2,5 vezes mais seguido"},
	{"id": "relampago", "name": "RELÂMPAGO", "blurb": "A partida dura 40% menos"},
	{"id": "forte", "name": "HABILIDADES FORTES", "blurb": "Os efeitos das habilidades duram e empurram 50% mais"},
	{"id": "arrancada", "name": "ARRANCADA", "blurb": "O sprint dura 50% mais"},
	{"id": "ceu", "name": "CÉU LIMPO", "blurb": "Os meteoros caem 2 vezes mais raro"},
]
const STRONG_PROPS := ["lasso_seconds", "emp_seconds", "trick_seconds", "frost_seconds", "cannon_push"]   # "forte": efeito x1,5


static func by_id(id: String) -> Dictionary:
	for m: Dictionary in CATALOG:
		if m["id"] == id:
			return m
	return {}


static func id_for_day(day: int) -> String:
	return CATALOG[posmod(day, CATALOG.size())]["id"]


static func today_id() -> String:
	return id_for_day(DailyMissions.today())


## Linha do menu: nome e o que muda.
static func menu_line(id: String) -> String:
	var m := by_id(id)
	return "" if m.is_empty() else "MUTADOR DE HOJE: %s\n%s" % [m["name"], m["blurb"]]


## Faixa curta do HUD no GO!.
static func banner(id: String) -> String:
	var m := by_id(id)
	return "" if m.is_empty() else "MUTADOR: %s" % m["name"]


## Multiplica os números da partida (a raiz tem Skills, Meteors e MatchTimer). Chamar UMA vez, depois de os _ready de todos rodarem.
static func apply(id: String, match_root: Node) -> void:
	var skills = match_root.get_node_or_null("Skills")
	var meteors = match_root.get_node_or_null("Meteors")
	var timer = match_root.get_node_or_null("MatchTimer")
	match id:
		"turbo":
			skills.sprint_cooldown *= 0.5
			skills.ability_cooldown *= 0.5
		"chuva":
			meteors.min_seconds_between *= 0.4
			meteors.max_seconds_between *= 0.4
		"relampago":
			timer.duration_seconds *= 0.6
			timer.restore_seconds(int(timer.duration_seconds))   # o relógio já nasceu com a duração cheia
		"forte":
			for prop: String in STRONG_PROPS:
				skills.set(prop, skills.get(prop) * 1.5)
		"arrancada":
			skills.sprint_seconds *= 1.5
		"ceu":
			meteors.min_seconds_between *= 2.0
			meteors.max_seconds_between *= 2.0
