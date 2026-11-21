extends SceneTree
## Teste de fumaça do Passo 148 (DD-187): o treino ensina o SPRINT e a HABILIDADE. (1) o sprint sai aos SPRINT_TIP_AT s, depois da dica de
## largada; (2) a habilidade sai quando a 1ª carga fica pronta (15 s da largada), com o NOME da habilidade, e espera a dica anterior acabar
## em vez de cortá-la; (3) quem já apertou o botão (sprint_used / ability_used do jogador) não vê a dica; o que é dos bots não conta;
## (4) sem SkillSystem (sem ability_charging) não há dica de habilidade; (5) em partida normal (`remember`) nenhuma das duas sai.
## Uso: godot_console --headless --path . -s res://tools/smoke_ability_tips.gd

const COACH := "res://scripts/ui/tutorial_coach.gd"
const FILE := "user://profile_smoke_ability_tips.json"

var _failed := false
var _bus: Node


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		DirAccess.remove_absolute(FILE)
		quit(1)


func _initialize() -> void:
	_run()


func _coach(remember := false) -> Control:
	var coach: Control = load(COACH).new()
	coach.set("remember", remember)
	root.add_child(coach)
	await process_frame   # o _ready do coach só roda no quadro seguinte
	return coach


func _run() -> void:
	_bus = root.get_node("EventBus")
	Profile.path = FILE
	Profile.data = Profile.defaults()

	# 1. Treino: largada -> sprint -> lembrete do circuito -> habilidade (esperou a anterior acabar)
	var coach := await _coach()
	_bus.match_started.emit()
	_bus.ability_charging.emit(1, 15.0, "emp")
	_check(Array(coach.shown) == ["steer"], "na largada só a dica de virar (%s)" % [coach.shown])
	coach._process(5.0)
	_check(Array(coach.shown) == ["steer"], "aos 5 s o sprint ainda não sai (%s)" % [coach.shown])
	coach._process(2.5)   # 7,5 s
	_check(Array(coach.shown) == ["steer", "sprint"] and coach.current_text().contains("SPRINT") and coach.current_text().contains("ALT"),
			"aos 7 s sai a dica do sprint (%s)" % [coach.shown])
	coach._process(7.0)   # 14,5 s: lembrete do circuito
	_check(Array(coach.shown) == ["steer", "sprint", "loop"], "aos 14 s o lembrete do circuito (%s)" % [coach.shown])
	coach._process(0.6)   # 15,1 s: a habilidade está pronta, mas o lembrete ainda está na tela
	_check(not coach.shown.has("ability"), "a habilidade não corta a dica que acabou de sair (%s)" % [coach.shown])
	coach._process(5.5)   # 20,6 s
	_check(Array(coach.shown) == ["steer", "sprint", "loop", "ability"], "a habilidade sai quando a anterior acabou (%s)" % [coach.shown])
	_check(coach.current_text().contains("Pulso EMP") and coach.current_text().contains("SHIFT"), "a dica traz o nome e a tecla (%s)" % coach.current_text())
	coach._process(100.0)
	_check(coach.shown.size() == 4, "cada dica sai uma vez só (%s)" % [coach.shown])
	coach.free()

	# 2. Quem já usou os botões não vê as dicas; o uso dos bots não conta
	var used := await _coach()
	_bus.match_started.emit()
	_bus.ability_charging.emit(2, 15.0, "heal")   # carga de um BOT: não marca a hora da dica do jogador
	_check(used.get("_ability_at") < 0.0, "a carga do bot não marca a dica da habilidade")
	_bus.ability_charging.emit(1, 15.0, "lasso")
	_bus.sprint_used.emit(2, 3.5)   # sprint do bot: não conta
	_bus.sprint_used.emit(1, 3.5)
	_bus.ability_used.emit(1, "lasso")
	used._process(100.0)
	_check(not used.shown.has("sprint") and not used.shown.has("ability"), "quem já usou os botões não vê as dicas (%s)" % [used.shown])
	used.free()
	var bots := await _coach()
	_bus.match_started.emit()
	_bus.sprint_used.emit(3, 3.5)
	_bus.ability_used.emit(3, "frost")
	bots._process(7.5)
	_check(bots.shown.has("sprint"), "o sprint do bot não apaga a dica do jogador (%s)" % [bots.shown])
	bots.free()

	# 3. Sem SkillSystem (nenhuma carga avisada) não há dica de habilidade
	var bare := await _coach()
	_bus.match_started.emit()
	bare._process(100.0)
	_check(bare.shown.has("sprint") and not bare.shown.has("ability"), "sem carga avisada só o sprint sai (%s)" % [bare.shown])
	bare.free()

	# 4. Partida normal (`remember`): nenhuma das duas
	var normal := await _coach(true)
	_bus.match_started.emit()
	_bus.ability_charging.emit(1, 15.0, "cannon")
	normal._process(100.0)
	_check(normal.shown.is_empty(), "partida normal não mostra as dicas do treino (%s)" % [normal.shown])
	normal.free()

	DirAccess.remove_absolute(FILE)
	if _failed:
		return
	print("OK: o treino ensina o sprint e a habilidade, sem cortar outra dica, e some para quem já usou")
	quit(0)
