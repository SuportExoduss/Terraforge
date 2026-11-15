class_name Cosmetics
extends RefCounted
## Cosméticos da loja (Passo 43; catálogo por dados no Passo 107, DD-147): uma tabela por CATEGORIA — cor da cerca (o rastro),
## moldura e título do perfil —, comprada com as moedas do perfil. Só aparência: nada aqui muda velocidade, vida ou território
## (sem pay-to-win, DD-144). O comprado e o equipado ficam no Profile ("owned_<cat>s", "equipped_<cat>"; a cerca mantém os nomes
## "owned_trails"/"equipped_trail" de sempre). Item novo = uma linha em CATALOG; categoria nova = uma linha em CATEGORIES + o
## lugar onde ela aparece. A partida lê `equipped_tint()`; o menu lê `frame_color()` e `title_text()`.
## ponytail: só moedas do jogo; GEMAS e passe de temporada (Passos 108/110) entram como preço/trilha nesta mesma tabela.

const CATEGORIES := [   # [categoria, rótulo da loja]
	["trail", "COR DA CERCA"],
	["frame", "MOLDURA DO PERFIL"],
	["title", "TÍTULO DO PERFIL"],
]
const RARITIES := {   # chave -> [nome, cor]; a raridade só colore e ordena, não dá poder
	"comum": ["Comum", Color(0.78, 0.8, 0.85)],
	"raro": ["Raro", Color(0.4, 0.7, 1.0)],
	"epico": ["Épico", Color(0.8, 0.5, 1.0)],
	"lendario": ["Lendário", Color(1.0, 0.75, 0.2)],
}
const CATALOG := {   # categoria -> [id, nome, preço, valor (Color da cerca/moldura; texto do título), raridade]
	"trail": [
		["default", "Original", 0, Color.WHITE, "comum"],
		["ouro", "Ouro", 60, Color(1.0, 0.8, 0.2), "comum"],
		["ciano", "Ciano", 80, Color(0.2, 0.9, 1.0), "comum"],
		["magenta", "Magenta", 100, Color(1.0, 0.3, 0.8), "raro"],
		["verde", "Verde neon", 120, Color(0.4, 1.0, 0.3), "raro"],
		["rubi", "Rubi", 180, Color(1.0, 0.2, 0.3), "epico"],
		["gelo", "Gelo", 260, Color(0.75, 0.92, 1.0), "epico"],
	],
	"frame": [
		["default", "Sem moldura", 0, Color(0.0, 0.0, 0.0, 0.0), "comum"],
		["bronze", "Bronze", 50, Color(0.8, 0.5, 0.25), "comum"],
		["prata", "Prata", 100, Color(0.8, 0.85, 0.92), "raro"],
		["ouro", "Ouro", 200, Color(1.0, 0.8, 0.2), "epico"],
		["aurora", "Aurora", 400, Color(0.45, 1.0, 0.8), "lendario"],
	],
	"title": [
		["default", "Sem título", 0, "", "comum"],
		["pioneiro", "Pioneiro", 40, "Pioneiro", "comum"],
		["cercador", "Mestre das Cercas", 120, "Mestre das Cercas", "raro"],
		["conquistador", "Conquistador de Mundos", 250, "Conquistador de Mundos", "epico"],
		["lenda", "Lenda do Planeta", 500, "Lenda do Planeta", "lendario"],
	],
}
const TINT_ALPHA := 0.55   # quanto da cor cobre o modelo da cerca


static func items(cat: String) -> Array:
	return CATALOG.get(cat, [])


static func entry(id: String, cat := "trail") -> Array:
	for item: Array in items(cat):
		if item[0] == id:
			return item
	return []


static func rarity_name(item: Array) -> String:
	return RARITIES[item[4]][0]


static func rarity_color(item: Array) -> Color:
	return RARITIES[item[4]][1]


static func owned(cat := "trail") -> Array:
	var list: Array = Profile.data.get("owned_%ss" % cat, [])
	return ["default"] + list.filter(func(id): return id != "default")


static func is_owned(id: String, cat := "trail") -> bool:
	return owned(cat).has(id)


static func equipped(cat := "trail") -> String:
	var id := String(Profile.data.get("equipped_" + cat, "default"))
	return id if is_owned(id, cat) else "default"


## Compra com as moedas do perfil; falha se o item não existe, já é seu ou falta moeda.
static func buy(id: String, cat := "trail") -> bool:
	var item := entry(id, cat)
	if item.is_empty() or is_owned(id, cat) or int(Profile.data["coins"]) < int(item[2]):
		return false
	Profile.data["coins"] = int(Profile.data["coins"]) - int(item[2])
	Profile.data["owned_%ss" % cat] = owned(cat) + [id]
	Profile.save()
	return true


static func equip(id: String, cat := "trail") -> bool:
	if not is_owned(id, cat):
		return false
	Profile.data["equipped_" + cat] = id
	Profile.save()
	return true


## Cor que a cerca do jogador recebe na partida; alfa 0 = sem tinta (cerca original).
static func equipped_tint() -> Color:
	var id := equipped()
	if id == "default":
		return Color(1.0, 1.0, 1.0, 0.0)
	var color: Color = entry(id)[3]
	return Color(color.r, color.g, color.b, TINT_ALPHA)


## Cor da moldura do perfil no menu; alfa 0 = sem moldura.
static func frame_color() -> Color:
	var color: Color = entry(equipped("frame"), "frame")[3]
	return color


## Título que aparece acima do nome do perfil; vazio = sem título.
static func title_text() -> String:
	return String(entry(equipped("title"), "title")[3])
