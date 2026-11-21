class_name Haptics
extends RefCounted
## Passo 133 (DD-172): vibração do celular nos momentos que importam (fechar área, cortar rastro, levar dano, ser eliminado,
## fim da partida). Só sensação, nunca regra (DD-143/144). Desligável em CONFIGURAÇÕES; no PC `vibrate_handheld` não faz nada.
## ponytail: um padrão curto por evento (ms, força 0..1); sem sequências de pulsos até haver aparelho para sentir e ajustar.

const PATTERNS := {
	"capture": [35, 0.4],
	"sprint": [40, 0.5],   # Passo 152: sprint, habilidade e defensor capturado
	"ability": [60, 0.7],
	"tame": [70, 0.6],
	"cut": [55, 0.6],
	"hit": [90, 0.9],
	"eliminated": [300, 1.0],
	"end": [140, 0.5],
}
const MIN_GAP_MSEC := 120   # pulsos colados viram um zumbido só; um mais forte ainda passa (ser eliminado logo depois de levar dano)

static var last_kind := ""   # o último pulso dado (os testes leem; sem aparelho não há como "sentir")
static var count := 0
static var _last_msec := -100000
static var _last_ms := 0
static var _connected := false


static func pulse(kind: String) -> void:
	if not PATTERNS.has(kind) or not Settings.haptics_on():
		return
	var pattern: Array = PATTERNS[kind]
	var now := Time.get_ticks_msec()
	if now - _last_msec < MIN_GAP_MSEC and int(pattern[0]) <= _last_ms:
		return
	_last_msec = now
	_last_ms = int(pattern[0])
	last_kind = kind
	count += 1
	Input.vibrate_handheld(int(pattern[0]), float(pattern[1]))


## Liga os pulsos aos eventos do JOGADOR (uma vez só; o `Services` chama ao nascer).
static func connect_events(bus: Object) -> void:
	if _connected:
		return
	_connected = true
	bus.territory_loop_claimed.connect(func(id: int, cells: int): if id == Civilization.PLAYER_ID and cells >= MatchStats.MIN_LOOP_CELLS: pulse("capture"))
	bus.trail_cut.connect(func(_victim: int, attacker: int): if attacker == Civilization.PLAYER_ID: pulse("cut"))
	bus.damage_taken.connect(func(victim: int, _points: int, _cause: String): if victim == Civilization.PLAYER_ID: pulse("hit"))
	bus.civilization_eliminated.connect(func(id: int): if id == Civilization.PLAYER_ID: pulse("eliminated"))
	bus.sprint_used.connect(func(id: int, _cooldown: float): if id == Civilization.PLAYER_ID: pulse("sprint"))
	bus.ability_used.connect(func(id: int, _kind: String): if id == Civilization.PLAYER_ID: pulse("ability"))
	bus.defender_captured.connect(func(conqueror: int, _victim: int): if conqueror == Civilization.PLAYER_ID: pulse("tame"))
	bus.match_ended.connect(func(): pulse("end"))
