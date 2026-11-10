class_name OnlineBoard
extends Control
## Passo 47: a partida online vista pelo cliente (Adendo 06). Desenha o planeta visto de cima do MEU corredor (a minha
## frente aponta para cima da tela) com os corredores do último snapshot do servidor, o tempo e o ranking, e manda a
## direção (← →) ao servidor. Quem manda é o servidor: aqui só se pede para virar e se mostra o que ele devolveu.
## ponytail: só pontos, sem o planeta 3D nem territórios (o cliente completo precisa da cena da partida); assume o centro
## do planeta na origem; uma paleta fixa de 6 cores, na ordem das civilizações.

const COLORS := [Color(1.0, 0.4, 0.3), Color(0.35, 0.65, 1.0), Color(0.45, 0.9, 0.45), Color(1.0, 0.85, 0.3), Color(0.8, 0.55, 1.0), Color(0.35, 0.9, 0.9)]

var net: NetSession
var _steer := 0.0


func _process(delta: float) -> void:
	if net == null:
		return
	var value := Input.get_axis("ui_left", "ui_right")
	if value != _steer:   # o servidor guarda a última direção: só preciso avisar quando ela muda
		_steer = value
		net.send_steer(value, delta)
	queue_redraw()


## A partida já passou do tempo (apuração, replay, resultados): o servidor decidiu o fim.
func over() -> bool:
	return net != null and net.last_snapshot.get("state", -1) >= MatchFlow.State.TIME_UP


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var shot := net.last_snapshot if net != null else {}
	if shot.is_empty():
		draw_string(font, Vector2(8, 28), "Aguardando a partida…", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		return
	var players: Array = shot.players
	var mine: Array = players.filter(func(p: Dictionary) -> bool: return p.id == net.my_civ)
	var middle := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 8.0
	draw_circle(middle, radius, Color(0.08, 0.12, 0.22))
	draw_arc(middle, radius, 0.0, TAU, 48, Color(0.4, 0.5, 0.7), 2.0)
	if not mine.is_empty():
		var up: Vector3 = mine[0].pos.normalized()
		var ahead: Vector3 = mine[0].fwd
		var right := ahead.cross(up)
		for p: Dictionary in players:
			var dir: Vector3 = p.pos.normalized()
			var color: Color = COLORS[(p.id - 1) % COLORS.size()]
			if not p.alive:
				color = Color(0.5, 0.5, 0.5)
			if dir.dot(up) < 0.0:
				color.a = 0.35   # o outro lado do planeta
			var at := middle + Vector2(dir.dot(right), -dir.dot(ahead)) * radius
			draw_circle(at, 7.0, color)
			if p.id == net.my_civ:
				draw_arc(at, 11.0, 0.0, TAU, 24, Color.WHITE, 2.0)
	draw_string(font, Vector2(8, 24), "Tempo %d:%02d" % [int(shot.left) / 60, int(shot.left) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var line := 0
	for id: int in shot.ranking:
		var dom := 0.0
		for p: Dictionary in players:
			if p.id == id:
				dom = p.dom
		draw_string(font, Vector2(size.x - 130, 24 + line * 22), "%dº  Civ %d  %d%%" % [line + 1, id, roundi(dom * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLORS[(id - 1) % COLORS.size()])
		line += 1
	draw_string(font, Vector2(8, size.y - 12.0), "Ping %d ms" % net.ping_ms(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if over():
		draw_string(font, Vector2(0.0, size.y - 12.0), "PARTIDA ENCERRADA", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24)
