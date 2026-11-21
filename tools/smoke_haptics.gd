extends SceneTree
## Teste de fumaça do Passo 133 (DD-172): VIBRAÇÃO. (1) só os eventos do JOGADOR vibram (fechar área grande, cortar, levar dano,
## ser eliminado, fim da partida); rival, área pequena e evento sem dono não; (2) o interruptor das CONFIGURAÇÕES desliga
## (padrão ligado, altura de dedo); (3) pulsos colados são unidos, mas um mais forte ainda passa (eliminado logo após dano).
## Perfil só dele. Uso: godot_console --headless --path . -s res://tools/smoke_haptics.gd

const TEST_PROFILE := "user://profile_smoke_haptics.json"


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	DirAccess.remove_absolute(TEST_PROFILE)
	quit(1)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # (com -s os autoloads só nascem no 1º quadro)
	var profile = load("res://scripts/core/profile.gd")
	profile.path = TEST_PROFILE
	profile.data = profile.defaults()
	profile.save()
	var haptics = load("res://scripts/core/haptics.gd")
	var settings = load("res://scripts/core/settings.gd")
	var bus: Node = root.get_node("EventBus")
	var player := 1

	if not settings.haptics_on():
		_fail("vibração vem ligada por padrão")
		return

	# 1. Só o jogador vibra, e cada evento tem o seu pulso
	var cases := [
		["fechar área grande", func(): bus.territory_loop_claimed.emit(player, 40), "capture"],
		["cortar rastro", func(): bus.trail_cut.emit(2, player), "cut"],
		["levar dano", func(): bus.damage_taken.emit(player, 1, "touro"), "hit"],
		["ser eliminado", func(): bus.civilization_eliminated.emit(player), "eliminated"],
		["sprint", func(): bus.sprint_used.emit(player, 3.5), "sprint"],
		["habilidade", func(): bus.ability_used.emit(player, "lasso"), "ability"],
		["capturar defensor", func(): bus.defender_captured.emit(player, 2), "tame"],
		["fim da partida", func(): bus.match_ended.emit(), "end"],
	]
	for c in cases:
		haptics._last_msec = -100000   # (o teste não espera o intervalo entre pulsos)
		haptics._last_ms = 0
		var before: int = haptics.count
		c[1].call()
		if haptics.count != before + 1 or haptics.last_kind != c[2]:
			_fail("%s deveria vibrar '%s' (veio '%s', %d pulsos)" % [c[0], c[2], haptics.last_kind, haptics.count - before])
			return
	var quiet := [
		["área pequena", func(): bus.territory_loop_claimed.emit(player, 3)],
		["área de rival", func(): bus.territory_loop_claimed.emit(2, 40)],
		["rival cortou outro rival", func(): bus.trail_cut.emit(3, 2)],
		["rival levou dano", func(): bus.damage_taken.emit(2, 1, "touro")],
		["rival eliminado", func(): bus.civilization_eliminated.emit(2)],
		["sprint de rival", func(): bus.sprint_used.emit(2, 3.5)],
		["habilidade de rival", func(): bus.ability_used.emit(2, "lasso")],
		["defensor perdido", func(): bus.defender_captured.emit(2, player)],
	]
	for q in quiet:
		haptics._last_msec = -100000
		haptics._last_ms = 0
		var before: int = haptics.count
		q[1].call()
		if haptics.count != before:
			_fail("%s não deveria vibrar" % q[0])
			return

	# 2. Desligar nas configurações: nada vibra; religar volta
	profile.data["settings"] = {"haptics": 0.0}
	haptics._last_msec = -100000
	haptics._last_ms = 0
	var off_before: int = haptics.count
	bus.trail_cut.emit(2, player)
	if settings.haptics_on() or haptics.count != off_before:
		_fail("vibração desligada não vibra")
		return
	profile.data["settings"] = {"haptics": 1.0}
	if not settings.haptics_on():
		_fail("vibração religada")
		return

	# 3. Pulsos colados: o segundo, do mesmo tamanho ou menor, some; um mais forte passa
	haptics._last_msec = -100000
	haptics._last_ms = 0
	var base: int = haptics.count
	bus.damage_taken.emit(player, 1, "touro")        # 90 ms
	bus.trail_cut.emit(2, player)                    # 55 ms, colado: unido
	if haptics.count != base + 1 or haptics.last_kind != "hit":
		_fail("pulso colado e mais fraco é unido (pulsos %d, último %s)" % [haptics.count - base, haptics.last_kind])
		return
	bus.civilization_eliminated.emit(player)         # 300 ms, colado mas mais forte: passa
	if haptics.count != base + 2 or haptics.last_kind != "eliminated":
		_fail("pulso mais forte passa mesmo colado (último %s)" % haptics.last_kind)
		return

	# 4. A tela de configurações tem o interruptor, com altura de dedo, e ele grava
	profile.data = profile.defaults()
	var panel: Control = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(panel)
	await process_frame
	var toggle: CheckButton = panel.find_child("Haptics", true, false)
	if toggle == null or not toggle.button_pressed or toggle.custom_minimum_size.y < 48.0:
		_fail("tela de configurações tem VIBRAÇÃO ligada e com altura de dedo")
		return
	toggle.button_pressed = false
	if settings.haptics_on() or not is_equal_approx(float(profile.data["settings"]["haptics"]), 0.0):
		_fail("desligar VIBRAÇÃO aplica e salva")
		return

	DirAccess.remove_absolute(TEST_PROFILE)
	print("OK")
	quit(0)
