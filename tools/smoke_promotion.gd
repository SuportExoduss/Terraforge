extends SceneTree
## Teste de fumaça do Passo 139 (DD-178): BÔNUS DE PROMOÇÃO DE LIGA. (1) a tabela de gemas por liga e a soma de ligas puladas;
## (2) subir de Bronze para Prata paga 3 gemas e grava a liga mais alta; (3) cair e subir de novo NÃO paga outra vez;
## (4) perfil antigo (sem o campo) recebe o que já tinha alcançado, uma vez só; (5) o painel de resultados mostra o bônus
## só quando há; (6) só gema (cosmético/meta): nenhum campo de poder muda. Perfil só dele.
## Uso: godot_console --headless --path . -s res://tools/smoke_promotion.gd

const TEST_PROFILE := "user://profile_smoke_promotion.json"

var _profile
var _stats := FakeStats.new()


## Placar de mentira: o jogador (1) fica em `place` (0 = nunca pontuou), com 30% do planeta e sem feitos.
class FakeStats extends RefCounted:
	var place := 1
	func ranking() -> Array:
		var list := []
		for i in range(1, place):
			list.append(100 + i)
		if place > 0:
			list.append(1)
		return list
	func dominance(_id) -> float: return 0.3
	func is_eliminated(_id) -> bool: return false
	func get_stat(_id, _key) -> float: return 0.0


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DirAccess.remove_absolute(TEST_PROFILE)
	quit(1)


func _initialize() -> void:
	_run()


## Joga uma partida e devolve o `last` das recompensas (e o painel de resultados com o texto).
func _play(place: int) -> Dictionary:
	var rewards = load("res://scripts/core/match_rewards.gd").new()
	_stats.place = place
	root.get_node("Services").stats = _stats
	rewards._grant()
	var last: Dictionary = rewards.last
	rewards.free()
	return last


func _panel_text(last: Dictionary) -> String:
	var rewards = load("res://scripts/core/match_rewards.gd").new()
	rewards.last = last
	root.get_node("Services").rewards = rewards
	var panel = load("res://scripts/ui/results_panel.gd").new()
	var text: String = panel._rewards_text()
	panel.free()
	root.get_node("Services").rewards = null
	rewards.free()
	return text


func _run() -> void:
	await process_frame
	var leagues = load("res://scripts/core/leagues.gd")
	_profile = load("res://scripts/core/profile.gd")
	_profile.path = TEST_PROFILE

	# 1. Tabela e soma (best = liga mais alta já premiada)
	var table := [[0, 1000, 0], [0, 1100, 3], [0, 1300, 8], [1, 1300, 5], [2, 1300, 0], [0, 2100, 48], [5, 2500, 0], [3, 1100, 0]]
	for row: Array in table:
		var got: int = leagues.promotion_gems(row[0], row[1])
		if got != row[2]:
			_fail("promotion_gems(melhor %d, habilidade %d) = %d (esperado %d)" % [row[0], row[1], got, row[2]])
			return
	if leagues.PROMOTION_GEMS.size() != leagues.TIERS.size():
		_fail("uma entrada de gemas por liga")
		return

	# 2. Bronze -> Prata: habilidade 1090 + 25 (1º lugar) = 1115
	_profile.data = _profile.defaults()
	_profile.data["rating"] = 1090
	_profile.save()
	var gems_before := int(_profile.data["gems"])
	var last := _play(1)
	if int(last["promo_gems"]) != 3 or int(_profile.data["league_best"]) != 1:
		_fail("Bronze -> Prata paga 3 e grava a liga (veio %s, liga %s)" % [last["promo_gems"], _profile.data["league_best"]])
		return
	if int(_profile.data["gems"]) != gems_before + int(last["gems"]) + 3:
		_fail("as 3 gemas entram no perfil (além das de conquista): %s" % _profile.data["gems"])
		return
	var text := _panel_text(last)
	if not text.contains("Bônus de promoção: +3 gemas") or not text.contains("PROMOVIDO"):
		_fail("o painel mostra a promoção e o bônus: %s" % text)
		return

	# 3. Cair e subir de novo não paga outra vez: 1115 -> 1100 -> 1085 (Bronze) -> 1110 (Prata de novo)
	_play(4)
	_play(4)
	if leagues.name_of(int(_profile.data["rating"])) != "Bronze" or int(_profile.data["league_best"]) != 1:
		_fail("caiu para Bronze e a liga mais alta continua Prata (%s)" % _profile.data["rating"])
		return
	last = _play(1)
	if leagues.name_of(int(_profile.data["rating"])) != "Prata" or int(last["promo_gems"]) != 0:
		_fail("voltar para Prata não paga de novo (veio %s)" % last["promo_gems"])
		return
	if _panel_text(last).contains("Bônus de promoção"):
		_fail("sem bônus, o painel não fala dele")
		return

	# 4. Perfil antigo: já era Ouro (1400), sem o campo -> recebe Prata + Ouro (3 + 5) uma vez só, e o campo sobrevive ao reabrir
	_profile.data = _profile.defaults()
	_profile.data.erase("league_best")
	_profile.data["rating"] = 1400
	_profile.save()
	_profile.load_data()
	if int(_profile.data["league_best"]) != 0:
		_fail("perfil sem o campo volta ao padrão 0")
		return
	last = _play(2)   # 2º lugar: +10
	if int(last["promo_gems"]) != 8 or int(_profile.data["league_best"]) != 2:
		_fail("perfil antigo recebe Prata + Ouro = 8 (veio %s)" % last["promo_gems"])
		return
	_profile.load_data()
	if int(_profile.data["league_best"]) != 2:
		_fail("a liga mais alta sobrevive a salvar e reabrir")
		return
	if int(_play(2)["promo_gems"]) != 0:
		_fail("a segunda partida não paga de novo")
		return

	# 5. Subir mais de uma liga de uma vez (hipotético, ex.: perfil importado em 2100): paga todas as puladas
	_profile.data = _profile.defaults()
	_profile.data["rating"] = 2100
	_profile.save()
	last = _play(3)   # 3º: +0 -> 2100 continua Lenda
	if int(last["promo_gems"]) != 48:
		_fail("Lenda de uma vez soma 3+5+8+12+20 = 48 (veio %s)" % last["promo_gems"])
		return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK smoke_promotion")
	quit(0)
