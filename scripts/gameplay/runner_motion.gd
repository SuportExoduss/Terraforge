class_name RunnerMotion
extends RefCounted
## O passo de movimento do corredor: UMA conta só, usada pelo servidor (PlanetRunner) e pela predição do
## cliente (RunnerPredictor, DD-044). Se divergissem, o cliente "errasse" sozinho a cada quadro.
## `planet` é qualquer objeto com `center` e `get_surface_radius(direção)` (o Planet, ou um falso nos testes).


## Gira `forward` ao redor do "up" local (direita = sentido negativo), avança sempre e recola na superfície REAL.
## Devolve [nova posição, nova direção tangente].
static func advance(position: Vector3, forward: Vector3, steer: float, delta: float, planet: Object,
		height_offset: float, speed: float, turn_degrees: float, push: Vector3 = Vector3.ZERO) -> Array:
	var center: Vector3 = planet.center
	var up := (position - center).normalized()
	var heading := forward.rotated(up, -steer * deg_to_rad(turn_degrees) * delta)
	var next := position + heading * (speed * delta) + push * delta
	var next_up := (next - center).normalized()
	next = center + next_up * (planet.get_surface_radius(next_up) + height_offset)
	heading = (heading - next_up * heading.dot(next_up)).normalized()   # continua tangente (sem erro acumulado)
	return [next, heading]
