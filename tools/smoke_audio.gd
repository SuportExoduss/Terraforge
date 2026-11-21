extends SceneTree
## Teste de fumaça do Passo 29 (módulo AUDIO, cap. 05): (1) os barramentos SFX e Música existem e o volume obedece;
## (2) todo som sintetizado tem a duração das suas notas e não é silêncio; (3) cada sinal do EventBus toca o som certo
## SÓ para o jogador local (circuito vazio, outro jogador e cura não tocam); (4) o mesmo som não empilha em 80 ms.
## Uso: godot_console --headless --path . -s res://tools/smoke_audio.gd

const PLAYER := 1
const OTHER := 2

var _match: Node
var _bus: Node
var _audio: Node
var _director: Script
var _failed := false


func _initialize() -> void:
	_director = load("res://scripts/audio/audio_director.gd")
	_match = load("res://scenes/match.tscn").instantiate()
	_match.get_node("MatchSetup").skip_ceremony = true
	_match.get_node("MatchSetup").bot_count = 0
	_match.get_node("Meteors").min_seconds_between = 100000.0
	_match.get_node("Meteors").max_seconds_between = 100000.0
	root.add_child(_match)
	_bus = root.get_node("EventBus")
	_audio = _match.get_node("Audio")
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok and not _failed:
		_failed = true
		print("FALHOU: ", msg)
		quit(1)


# Dispara `action`, espera passar o intervalo anti-empilhamento e confere os sons tocados.
func _expect(label: String, action: Callable, expected: Array) -> void:
	_audio.played.clear()
	action.call()
	await create_timer(0.1).timeout
	_check(_audio.played == expected, "%s: tocou %s, esperado %s" % [label, _audio.played, expected])


func _run() -> void:
	await _bus.match_started
	await create_timer(0.5).timeout   # a contagem de abertura e a vida inicial já passaram

	# 1. Barramentos e volume
	for bus_name in ["SFX", "Música"]:
		var index := AudioServer.get_bus_index(bus_name)
		_check(index != -1, "falta o barramento %s" % bus_name)
		_check(AudioServer.get_bus_send(index) == &"Master", "%s deve sair no Master" % bus_name)
	_director.set_volume("SFX", 0.5)
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - (-6.02)) < 0.1, "volume 0,5 = -6 dB")
	_director.set_volume("SFX", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "volume 0 = mudo")
	_director.set_volume("SFX", 1.0)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "volume 1 desfaz o mudo")

	# 2. Síntese: duração = soma das notas, e há sinal audível
	for sound in _director.SOUNDS:
		var notes: Array = _director.SOUNDS[sound]
		var expected_samples := 0
		for note in notes:
			expected_samples += int(note[2] * _director.RATE)
		var wav: AudioStreamWAV = _audio.stream(sound)
		_check(wav.data.size() == expected_samples * 2, "%s: %d bytes, esperado %d" % [sound, wav.data.size(), expected_samples * 2])
		var peak := 0
		for i in range(0, wav.data.size(), 2):
			peak = maxi(peak, absi(wav.data.decode_s16(i)))
		_check(peak > 3000, "%s está quase mudo (pico %d)" % [sound, peak])

	# 3. Eventos -> sons (só o jogador local)
	await _expect("circuito grande", func(): _bus.territory_loop_claimed.emit(PLAYER, 20), ["capture"])
	await _expect("circuito vazio", func(): _bus.territory_loop_claimed.emit(PLAYER, 3), [])
	await _expect("circuito de outro", func(): _bus.territory_loop_claimed.emit(OTHER, 20), [])
	await _expect("conversão", func(): _bus.territory_cells_converted.emit(PLAYER, 0.05), [_director.convert_sound(_audio.civilization)])
	await _expect("conversão de outro", func(): _bus.territory_cells_converted.emit(OTHER, 0.05), [])
	await _expect("corte dado", func(): _bus.trail_cut.emit(OTHER, PLAYER), ["cut"])
	for r in get_nodes_in_group("runners"):
		if r.get_node("Civilization").id == PLAYER:
			r.get_node("Health").shield_left = 0.0   # Passo 73: o pouso da abertura dá 2 s de proteção
	await _expect("corte sofrido (o som vem da vida real do jogador)", func(): _bus.trail_cut.emit(PLAYER, OTHER), ["damage"])
	await _expect("bônus", func(): _bus.bonus_activated.emit(PLAYER, "SPEED", 5.0), ["bonus"])
	await _expect("bônus de outro", func(): _bus.bonus_activated.emit(OTHER, "SPEED", 5.0), [])
	await _expect("sprint", func(): _bus.sprint_used.emit(PLAYER, 3.5), ["sprint"])
	await _expect("sprint de outro", func(): _bus.sprint_used.emit(OTHER, 3.5), [])
	await _expect("habilidade", func(): _bus.ability_used.emit(PLAYER, "lasso"), ["ability"])
	await _expect("habilidade de outro", func(): _bus.ability_used.emit(OTHER, "lasso"), [])
	await _expect("defensor capturado", func(): _bus.defender_captured.emit(PLAYER, OTHER), ["tame"])
	await _expect("defensor perdido (vítima não toca)", func(): _bus.defender_captured.emit(OTHER, PLAYER), [])
	await _expect("aviso de evento", func(): _bus.global_event_warning.emit("METEORO", 3), ["warning"])
	await _expect("contagem 3", func(): _bus.respawn_countdown.emit(PLAYER, 3), ["tick"])
	await _expect("contagem de outro", func(): _bus.respawn_countdown.emit(OTHER, 3), [])
	await _expect("GO", func(): _bus.respawn_countdown.emit(PLAYER, 0), ["go"])
	_bus.health_changed.emit(PLAYER, 16, 16)
	await _expect("dano na vida", func(): _bus.health_changed.emit(PLAYER, 14, 16), ["damage"])
	await _expect("cura não toca", func(): _bus.health_changed.emit(PLAYER, 15, 16), [])
	await _expect("dano em outro", func(): _bus.health_changed.emit(OTHER, 1, 16), [])
	await _expect("eliminação", func(): _bus.civilization_eliminated.emit(PLAYER), ["eliminated"])
	await _expect("eliminação de outro", func(): _bus.civilization_eliminated.emit(OTHER), [])

	# 4. Anti-empilhamento: dois circuitos em seguida = um só som
	_audio.played.clear()
	_bus.territory_loop_claimed.emit(PLAYER, 20)
	_bus.territory_loop_claimed.emit(PLAYER, 30)
	_check(_audio.played == ["capture"], "o mesmo som não pode empilhar em 80 ms: %s" % [_audio.played])

	# 5. Fim da partida (por último: o resto da máquina de estados também reage)
	await create_timer(0.1).timeout
	await _expect("fim da partida", func(): _bus.match_ended.emit(), ["end"])

	if not _failed:
		print("OK")
		quit(0)
