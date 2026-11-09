class_name Cosmetics
extends RefCounted
## Cosméticos da loja (Passo 43): cor da cerca (o rastro) do jogador, comprada com as moedas do perfil. Só aparência:
## nada aqui muda velocidade, vida ou território (sem pay-to-win). O comprado e o equipado ficam no Profile
## ("owned_trails", "equipped_trail"); a partida lê `equipped_tint()`.
## ponytail: só a cor da cerca; Passe, Eventos e outros cosméticos (marca no chão, comemoração) ficam para depois.

const TRAILS := [   # [id, nome, preço, cor]
	["default", "Original", 0, Color.WHITE],
	["ouro", "Ouro", 60, Color(1.0, 0.8, 0.2)],
	["ciano", "Ciano", 80, Color(0.2, 0.9, 1.0)],
	["magenta", "Magenta", 100, Color(1.0, 0.3, 0.8)],
	["verde", "Verde neon", 120, Color(0.4, 1.0, 0.3)],
]
const TINT_ALPHA := 0.55   # quanto da cor cobre o modelo da cerca


static func entry(id: String) -> Array:
	for item: Array in TRAILS:
		if item[0] == id:
			return item
	return []


static func owned() -> Array:
	var list: Array = Profile.data.get("owned_trails", [])
	return ["default"] + list.filter(func(id): return id != "default")


static func is_owned(id: String) -> bool:
	return owned().has(id)


static func equipped() -> String:
	var id := String(Profile.data.get("equipped_trail", "default"))
	return id if is_owned(id) else "default"


## Compra com as moedas do perfil; falha se o item não existe, já é seu ou falta moeda.
static func buy(id: String) -> bool:
	var item := entry(id)
	if item.is_empty() or is_owned(id) or int(Profile.data["coins"]) < int(item[2]):
		return false
	Profile.data["coins"] = int(Profile.data["coins"]) - int(item[2])
	Profile.data["owned_trails"] = owned() + [id]
	Profile.save()
	return true


static func equip(id: String) -> bool:
	if not is_owned(id):
		return false
	Profile.data["equipped_trail"] = id
	Profile.save()
	return true


## Cor que a cerca do jogador recebe na partida; alfa 0 = sem tinta (cerca original).
static func equipped_tint() -> Color:
	var id := equipped()
	if id == "default":
		return Color(1.0, 1.0, 1.0, 0.0)
	var color: Color = entry(id)[3]
	return Color(color.r, color.g, color.b, TINT_ALPHA)
