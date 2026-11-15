extends RefCounted
## Passe de temporada, trilha grátis (Passo 123, DD-163): cada partida rende XP do passe (o mesmo XP da partida); a cada TIER_XP
## abre um nível com uma recompensa (moedas, gemas ou um cosmético EXCLUSIVO do passe), resgatada na tela PASSE.
## Só aparência e moedas: nada aqui muda a regra da partida (sem pay-to-win, DD-144). 20 níveis ≈ 20 partidas.
## ponytail: temporada única sem prazo e sem trilha paga; a trilha paga (gemas) e o relógio do servidor entram com a conta de loja.
## Dados: `Profile.data["pass"] = {xp, claimed[níveis resgatados]}`. Sem class_name (use preload).

const TIER_XP := 150
# nível n (1..20) -> [tipo, valor]; tipo = coins | gems | trail | frame | title (cosmético: valor = id)
const TRACK := [
	["coins", 30], ["coins", 40], ["gems", 2], ["coins", 50], ["trail", "eclipse"],
	["coins", 60], ["gems", 3], ["coins", 70], ["coins", 80], ["frame", "forja"],
	["coins", 90], ["gems", 4], ["coins", 100], ["coins", 110], ["gems", 5],
	["coins", 120], ["coins", 130], ["gems", 5], ["coins", 150], ["title", "forjador"],
]


static func _state() -> Dictionary:
	var p: Dictionary = Profile.data.get("pass", {})
	if p.is_empty():
		p = {"xp": 0, "claimed": []}
		Profile.data["pass"] = p
	return p


static func xp() -> int:
	return int(_state()["xp"])


## Níveis já alcançados (0..TRACK.size()).
static func tiers_reached() -> int:
	return mini(floori(xp() / float(TIER_XP)), TRACK.size())


## XP andado dentro do nível atual (0 ao completar o passe).
static func xp_in_tier() -> int:
	return 0 if tiers_reached() >= TRACK.size() else xp() % TIER_XP


static func is_claimed(tier: int) -> bool:
	return _state()["claimed"].has(str(tier))   # texto: o JSON devolve números como decimais e Array.has(5) não acha 5.0


## Níveis alcançados e ainda não resgatados (o aviso do menu).
static func claimable() -> int:
	return tiers_reached() - _state()["claimed"].size()


## Chamado pelo MatchRewards ao fechar a partida (antes de gravar o perfil).
static func add_xp(amount: int) -> void:
	var p := _state()
	p["xp"] = int(p["xp"]) + maxi(amount, 0)


## Resgata o nível `tier` (1..20) se alcançado e ainda não resgatado. Grava o perfil.
static func claim(tier: int) -> bool:
	if tier < 1 or tier > tiers_reached() or is_claimed(tier):
		return false
	var kind: String = TRACK[tier - 1][0]
	var value: Variant = TRACK[tier - 1][1]
	if kind == "coins" or kind == "gems":
		Profile.data[kind] = int(Profile.data.get(kind, 0)) + int(value)
	else:
		Cosmetics.grant(String(value), kind)
	_state()["claimed"].append(str(tier))
	Profile.save()
	return true


## "30 moedas", "2 gemas" ou "Eclipse (cor da cerca)".
static func reward_text(tier: int) -> String:
	var kind: String = TRACK[tier - 1][0]
	var value: Variant = TRACK[tier - 1][1]
	match kind:
		"coins":
			return "%d moedas" % int(value)
		"gems":
			return "%d gemas" % int(value)
	var label := {"trail": "cor da cerca", "frame": "moldura", "title": "título"}[kind] as String
	return "%s (%s)" % [Cosmetics.entry(String(value), kind)[1], label]


## Cor do cartão da recompensa: a raridade do cosmético; moedas neutro, gemas ciano.
static func reward_color(tier: int) -> Color:
	var kind: String = TRACK[tier - 1][0]
	if kind == "coins":
		return Cosmetics.RARITIES["comum"][1]
	if kind == "gems":
		return Color(0.4, 0.9, 1.0)
	return Cosmetics.rarity_color(Cosmetics.entry(String(TRACK[tier - 1][1]), kind))


## Linha da tela de resultados: "Passe: nível 4/20 · 60/150" (e o aviso quando a partida abriu recompensa nova).
static func result_line(tiers_before: int) -> String:
	var now := tiers_reached()
	if now >= TRACK.size():
		return "Passe completo ✓" if tiers_before >= now else "[b]Passe completo![/b] Resgate no menu"
	var line := "Passe: nível %d/%d  ·  %d/%d" % [now, TRACK.size(), xp_in_tier(), TIER_XP]
	return line + ("\n[b]Recompensa nova no PASSE![/b]" if now > tiers_before else "")
