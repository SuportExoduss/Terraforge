class_name MatchFlow
extends Node
## Máquina de estados da partida (cap. 04, parte 01) na versão local. STATE-001…003 (servidor, matchmaking, lobby)
## não existem offline; os demais seguem a ordem do GDMD: LOADING=004, SPAWN=005, COUNTDOWN=006, PLAYING=007,
## EVENT_ACTIVE=008, TIME_UP=009, TALLY=010 (apuração), REPLAY=011, RESULTS=012, MENU=013.
## Regras: nenhum estado é pulado (pedir um adiante passa por todos os do meio) e nunca se volta — a única exceção é
## EVENT_ACTIVE→PLAYING (evento global acabou). EVENT_ACTIVE é opcional: some do caminho se nenhum evento ocorreu.
## Os módulos continuam reagindo aos sinais de sempre; quem quer o fluxo da partida ouve match_state_changed.
## ponytail: sem servidor; o pós-jogo (TIME_UP→TALLY→REPLAY→RESULTS) é por pausas fixas, ritmo ajustável em `pace`.

enum State { LOADING, SPAWN, COUNTDOWN, PLAYING, EVENT_ACTIVE, TIME_UP, TALLY, REPLAY, RESULTS, MENU }

@export var time_up_seconds := 4.0     # STATE-009: todos param e a câmera sobe para o planeta
@export var tally_seconds := 2.0       # STATE-010: apuração
@export var replay_seconds := 12.0     # STATE-011: replay cinematográfico (MatchReplay repinta o planeta neste tempo)
@export var pace := 1.0                # multiplica as pausas do pós-jogo; 0 = instantâneo (testes)

var state := State.LOADING

var _events_active := 0
var _wait := 0.0


func _ready() -> void:
	Services.flow = self
	EventBus.respawn_countdown.connect(func(_id: int, _seconds: int): if state == State.SPAWN: go(State.COUNTDOWN))
	EventBus.match_started.connect(func(): go(State.PLAYING))
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.global_event_active_changed.connect(_on_event_active)


func _exit_tree() -> void:
	if Services.flow == self:
		Services.flow = null


func _process(delta: float) -> void:
	if state == State.LOADING and Services.planet != null and Services.planet.surface_ready:
		go(State.SPAWN)   # o planeta existe: as naves começam a descer
	_wait -= delta
	_advance_post()


## Pede um estado. Para frente passa por todos os intermediários; para trás só vale EVENT_ACTIVE→PLAYING.
func go(target: State) -> void:
	if target < state:
		if state == State.EVENT_ACTIVE and target == State.PLAYING:
			_enter(target)
		return
	while state != target:
		var next := state + 1 as State
		if next == State.EVENT_ACTIVE and target != State.EVENT_ACTIVE:
			next = State.TIME_UP   # evento é opcional
		_enter(next)


func _enter(next: State) -> void:
	state = next
	_wait = _pause(next) * pace
	EventBus.match_state_changed.emit(state)


func _pause(of: State) -> float:
	match of:
		State.TIME_UP: return time_up_seconds
		State.TALLY: return tally_seconds
		State.REPLAY: return replay_seconds
	return 0.0


func _on_match_ended() -> void:
	go(State.TIME_UP)
	_advance_post()


# Com as pausas esgotadas, o pós-jogo anda sozinho até a tela de resultados.
func _advance_post() -> void:
	while _wait <= 0.0 and state >= State.TIME_UP and state < State.RESULTS:
		go(state + 1 as State)


func _on_event_active(active: bool) -> void:
	_events_active = maxi(0, _events_active + (1 if active else -1))
	if state == State.PLAYING and _events_active > 0:
		go(State.EVENT_ACTIVE)
	elif state == State.EVENT_ACTIVE and _events_active == 0:
		go(State.PLAYING)
