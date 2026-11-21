extends SceneTree
## SIMULADOR DE EQUILÍBRIO (Passo 153, DD-192): joga UMA partida só de bots (a vaga do jogador também é bot) e imprime, por civilização,
## a habilidade do bioma dela, o território final e quantas vezes usou sprint/habilidade. Quem agrega várias partidas é tools/sim_balance.sh.
## Não é teste de passa/falha: é uma medição (o André decide o ajuste olhando a tabela).
## Uso: godot_console --headless --path . --fixed-fps 60 -s res://tools/sim_balance.gd   (SEM --quiet: ele engole os print)
## Variáveis: SIM_SECONDS (duração da partida, padrão 240), SIM_BOTS (padrão 5 = as 6 civilizações), SIM_SPEED (Engine.time_scale, padrão 1;
## acima de 1 o resultado DISTORCE: a 8x os bots só chegaram a 4% do planeta em 240 s contra 10-23% a 1x). 240 s de jogo levam ~90 s de relógio.

var _match: Node
var _bus: Node
var _services: Node
var _t := 0.0
var _limit := 0.0
var _sprints := {}
var _abilities := {}


func _initialize() -> void:
	var seconds := float(OS.get_environment("SIM_SECONDS")) if OS.get_environment("SIM_SECONDS") != "" else 240.0
	var bots := int(OS.get_environment("SIM_BOTS")) if OS.get_environment("SIM_BOTS") != "" else 5
	load("res://scripts/core/profile.gd").path = "user://profile_sim.json"   # nunca mexe no perfil do André
	_limit = seconds + 120.0
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = bots
	_match.get_node("MatchTimer").duration_seconds = seconds
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_services = root.get_node("Services")
	_bus.sprint_used.connect(func(id: int, _cooldown: float) -> void: _sprints[id] = _sprints.get(id, 0) + 1)
	_bus.ability_used.connect(func(id: int, _kind: String) -> void: _abilities[id] = _abilities.get(id, 0) + 1)
	_bus.match_ended.connect(_report)
	await process_frame
	_take_the_wheel()
	Engine.time_scale = float(OS.get_environment("SIM_SPEED")) if OS.get_environment("SIM_SPEED") != "" else 1.0


# O jogador vira um bot igual aos outros (mesma ambição e cobiça por regra), para as seis civilizações jogarem em pé de igualdade.
func _take_the_wheel() -> void:
	var brain: Node = load("res://scripts/ai/bot_steering.gd").new()
	brain.ambition = load("res://scripts/ai/bot_steering.gd").ambition_for(int(load("res://scripts/core/profile.gd").data.get("rating", 0)))
	brain.greed = load("res://scripts/ai/bot_steering.gd").greed_for(1)
	for runner in get_nodes_in_group("runners"):
		if runner.get_node("Civilization").id == 1:
			runner.use_steering(brain)


func _process(delta: float) -> bool:
	_t += delta
	if _t > _limit:
		print("FALHOU: a partida não terminou em %.0f s de jogo" % _limit)
		quit(1)
	return false


func _report() -> void:
	var ids: Array = []
	for runner in get_nodes_in_group("runners"):
		ids.append(runner.get_node("Civilization").id)
	ids.sort()
	var winner := 0
	var best := -1.0
	var catalog: Object = load("res://scripts/core/civilization_catalog.gd")
	for id: int in ids:
		var pct: float = _services.territory.owned_fraction(id) * 100.0
		if pct > best:
			best = pct
			winner = id
		print("SIM ability=%s civ=%d pct=%.2f sprints=%d abilities=%d" % [catalog.ability_of(catalog.biome_of(id))["id"], id, pct, _sprints.get(id, 0), _abilities.get(id, 0)])
	print("WIN ability=%s civ=%d pct=%.2f" % [catalog.ability_of(catalog.biome_of(winner))["id"], winner, best])
	quit(0)
