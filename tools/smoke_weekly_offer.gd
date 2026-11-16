extends SceneTree
## Teste de fumaça do Passo 134 (DD-173): OFERTA DA SEMANA. (1) a oferta é a mesma a semana inteira (segunda a domingo) e
## troca na segunda; (2) só entra item à venda (nunca passe/conquista/grátis) e todos os 15 passam por ela; (3) o preço da oferta é
## 25% menor, só nela; (4) compra cobra o preço com desconto (e não cobra se falta 1), e a oferta some depois de comprada;
## (5) a loja mostra a faixa da oferta, o aviso "OFERTA" na linha e o preço com desconto no botão. Perfil só dele.
## Uso: godot_console --headless --path . -s res://tools/smoke_weekly_offer.gd

const TEST_PROFILE := "user://profile_smoke_weekly_offer.json"
const MONDAY := 4   # 1970-01-05 foi segunda-feira


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DirAccess.remove_absolute(TEST_PROFILE)
	quit(1)


func _initialize() -> void:
	_run()


func _run() -> void:
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	profile.data = profile.defaults()
	profile.save()
	var cos = load("res://scripts/core/cosmetics.gd")
	var missions = load("res://scripts/core/daily_missions.gd")

	# 1. Mesma oferta de segunda a domingo; troca na segunda seguinte e no domingo anterior à segunda
	var week: Array = cos.weekly_offer(MONDAY)
	if week.size() != 2:
		_fail("há oferta numa conta nova")
		return
	for d in range(MONDAY, MONDAY + 7):
		if cos.weekly_offer(d) != week:
			_fail("a oferta muda no meio da semana (dia %d)" % d)
			return
	if cos.weekly_offer(MONDAY + 7) == week or cos.weekly_offer(MONDAY - 1) == week:
		_fail("a oferta deveria trocar na segunda (antes e depois)")
		return

	# 2. Só item à venda, e o catálogo à venda inteiro passa pela vitrine em 15 semanas
	var seen := {}
	for w in range(1, 31):
		var offer: Array = cos.weekly_offer(7 * w - 3)
		var item: Array = cos.entry(offer[1], offer[0])
		if item.is_empty() or cos.unbuyable(item) or int(item[2]) <= 0:
			_fail("a oferta da semana %d não é um item à venda: %s" % [w, offer])
			return
		seen[offer[0] + "/" + offer[1]] = true
	if seen.size() != 15:
		_fail("os 15 itens à venda deveriam passar pela oferta em 30 semanas (passaram %d)" % seen.size())
		return

	# 3. Preço: 25% menos só no item da oferta ("ouro" da cerca ≠ "ouro" da moldura)
	var day := -1
	for w in range(1, 40):
		if cos.weekly_offer(7 * w - 3) == ["trail", "ouro"]:
			day = 7 * w - 3
			break
	if day < 0:
		_fail("a cerca Ouro entra na oferta em algum momento")
		return
	missions.day_override = day
	var ouro: Array = cos.entry("ouro", "trail")
	var frame_ouro: Array = cos.entry("ouro", "frame")
	var ciano: Array = cos.entry("ciano", "trail")
	var expected := roundi(int(ouro[2]) * 0.75)
	if cos.price_of(ouro, "trail") != expected or expected >= int(ouro[2]):
		_fail("a oferta custa 25%% menos (%d de %d)" % [cos.price_of(ouro, "trail"), int(ouro[2])])
		return
	if cos.price_of(frame_ouro, "frame") != int(frame_ouro[2]) or cos.price_of(ciano, "trail") != int(ciano[2]) or cos.price_of(ouro) != int(ouro[2]):
		_fail("só o item da oferta tem desconto (moldura Ouro, cerca Ciano e consulta sem categoria ficam cheios)")
		return
	if cos.price_text(ouro, "trail") != str(expected) or cos.price_text(ouro) != str(int(ouro[2])):
		_fail("o texto do preço acompanha o desconto")
		return

	# 5. A loja mostra a faixa, o aviso na linha e o preço com desconto (antes de comprar)
	profile.data["coins"] = expected
	var screen = load("res://scripts/ui/shop_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var banner: Label = screen.find_child("Offer", true, false)
	var row_deal: Label = screen.find_child("Deal", true, false)
	var b_ouro: Button = screen.find_child("Item_trail_ouro", true, false)
	var b_ciano: Button = screen.find_child("Item_trail_ciano", true, false)
	if banner == null or not banner.visible or not banner.text.contains("Ouro") or not banner.text.contains(str(expected)):
		_fail("a faixa mostra a oferta e o preço novo (%s)" % (banner.text if banner else "sem faixa"))
		return
	if b_ouro == null or b_ouro.text != "COMPRAR  (%d)" % expected or b_ouro.disabled:
		_fail("o botão da oferta mostra o preço com desconto e cabe no saldo (%s)" % (b_ouro.text if b_ouro else "sem botão"))
		return
	var deals_visible := 0
	for deal: Node in screen.find_children("Deal", "Label", true, false):
		if deal.visible:
			deals_visible += 1
	if deals_visible != 1 or row_deal == null or b_ciano == null or b_ciano.text != "COMPRAR  (%d)" % int(ciano[2]) or not b_ciano.disabled:
		_fail("só uma linha tem o aviso e as outras mantêm o preço cheio (avisos visíveis: %d)" % deals_visible)
		return
	if b_ouro.size.y > 0.0 and b_ouro.size.y < 47.0:
		_fail("botão com altura de dedo")
		return

	# 4. Compra: falta 1 moeda = nada acontece; saldo exato = compra e zera; a oferta some depois de comprada
	profile.data["coins"] = expected - 1
	if cos.can_afford(ouro, "trail") or cos.buy("ouro", "trail") or int(profile.data["coins"]) != expected - 1:
		_fail("faltando 1 moeda para o preço com desconto não compra nem cobra")
		return
	profile.data["coins"] = expected
	if not cos.can_afford(ouro, "trail") or not cos.buy("ouro", "trail") or int(profile.data["coins"]) != 0 or not cos.is_owned("ouro", "trail"):
		_fail("saldo exato do preço com desconto compra e zera a carteira")
		return
	if cos.weekly_offer() != [] or cos.is_on_offer(ouro, "trail"):
		_fail("depois de comprar, a oferta some até a próxima segunda")
		return
	b_ouro.pressed.emit()   # a loja se atualiza sozinha ao apertar; aqui só relê o estado
	await process_frame
	if banner.visible:
		_fail("a faixa some quando a oferta já é do jogador")
		return
	if cos.weekly_offer(day + 7).is_empty():
		_fail("na semana seguinte há oferta nova")
		return

	# Lendário: o desconto vale em gemas
	var legendary_day := -1
	for w in range(1, 40):
		if cos.weekly_offer(7 * w - 3) == ["trail", "nova"]:
			legendary_day = 7 * w - 3
			break
	missions.day_override = legendary_day
	var nova: Array = cos.entry("nova", "trail")
	if cos.currency(nova) != "gems" or cos.price_of(nova, "trail") != roundi(int(nova[2]) * 0.75) or not cos.price_text(nova, "trail").ends_with("gemas"):
		_fail("a oferta lendária também tem 25%% menos, em gemas (%s)" % cos.price_text(nova, "trail"))
		return

	missions.day_override = -1
	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
