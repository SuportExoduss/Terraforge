class_name RemoteSteering
extends Node
## Motorista de um jogador remoto: o corredor obedece ao último comando VÁLIDO que o servidor aceitou.
## Mesmo contrato de PlayerSteering/BotSteering: get_steer() de -1 a 1.

var steer := 0.0


func get_steer() -> float:
	return steer
