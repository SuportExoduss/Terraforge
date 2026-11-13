class_name MatchTimer
extends Node
## O relógio da partida (DD-111: 10 minutos). Só corre a partir do GO! (DD-096); anuncia cada segundo
## restante e, uma única vez, o fim — quem deve reagir (corredor, HUD, resultados) decide pelo EventBus.

@export var duration_seconds := 600.0

var _remaining := 0.0
var _last_announced := -1
var _running := false
var _ended := false


func _ready() -> void:
	add_to_group("match_timer")
	_remaining = duration_seconds
	EventBus.match_started.connect(func(): _running = true)


func _process(delta: float) -> void:
	if not _running or _ended:
		return
	_remaining -= delta
	var whole := maxi(0, ceili(_remaining))   # só anuncia na virada do segundo
	if whole != _last_announced:
		_last_announced = whole
		EventBus.match_clock_changed.emit(whole)
	if _remaining <= 0.0:
		_ended = true
		EventBus.match_ended.emit()
		GameLog.say("[Core] Fim da partida! O planeta fica para contemplação.")


## Recuperação do servidor: volta o relógio ao valor salvo.
func restore_seconds(seconds: int) -> void:
	_remaining = float(seconds)


## Segundos que faltam (quem nasce no meio da partida, como o servidor ou um cliente que volta, lê direto daqui).
func seconds_left() -> int:
	return maxi(0, ceili(_remaining))
