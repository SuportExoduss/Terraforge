class_name MatchLobby
extends Node
## Sala da partida no servidor (DD-134; cap. 04 parte 01, STATE-001…003; cap. 03 parte 02 "Matchmaking"): SERVER_INIT (servidor
## de pé) → MATCHMAKING (junta jogadores) → CLOSED (lobby fechado: ninguém mais entra e a partida carrega).
## A sala fecha quando enche (`capacity`) ou quando o tempo máximo de espera (`max_wait`) acaba; as vagas que sobram
## são completadas com bots inteligentes (`bots()`), porque "o jogador nunca deve aguardar excessivamente".
## O relógio da espera só corre com pelo menos `min_humans` na sala: sala vazia espera para sempre, não abre partida de bots.
## ponytail: sala única, sem habilidade/latência (os critérios do GDMD entram com vários servidores); decide só o número.

signal changed                                   # entrou ou saiu alguém, ou a fase mudou: quem está na sala precisa saber
signal closed(peers: Array, bots: int)           # lobby fechado: quem entra na partida e quantos bots completam

enum Phase { SERVER_INIT, MATCHMAKING, CLOSED }

const MAX_CAPACITY := 6   # 1 jogador + 5 bots: o máximo do MatchSetup

var phase := Phase.SERVER_INIT
var capacity := 4:
	set(value):
		capacity = clampi(value, 1, MAX_CAPACITY)
var max_wait := 20.0   # s a partir do primeiro jogador
var min_humans := 1
var peers: Array = []  # peer_ids na ordem de chegada

var _waited := 0.0


func open() -> void:
	if phase == Phase.SERVER_INIT:
		_set_phase(Phase.MATCHMAKING)


## Um jogador entra na sala. Falso: sala fechada (ou ainda não aberta), já está nela, ou está cheia.
func add(peer_id: int) -> bool:
	if phase != Phase.MATCHMAKING or peers.has(peer_id) or peers.size() >= capacity:
		return false
	peers.append(peer_id)
	changed.emit()
	if peers.size() >= capacity:
		close()
	return true


func remove(peer_id: int) -> void:
	if phase != Phase.MATCHMAKING or not peers.has(peer_id):
		return
	peers.erase(peer_id)
	if peers.size() < min_humans:
		_waited = 0.0   # a sala esvaziou: a espera recomeça com o próximo
	changed.emit()


func bots() -> int:
	return capacity - peers.size()


func seconds_left() -> float:
	return maxf(max_wait - _waited, 0.0)


func close() -> void:
	if phase == Phase.MATCHMAKING:
		_set_phase(Phase.CLOSED)
		closed.emit(peers.duplicate(), bots())


func _process(delta: float) -> void:
	if phase == Phase.MATCHMAKING and peers.size() >= min_humans:
		_waited += delta
		if _waited >= max_wait:
			close()


func _set_phase(next: Phase) -> void:
	phase = next
	changed.emit()
