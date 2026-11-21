class_name MinimapMarkers
extends Control
## Camada estratégica do minimapa (MP-003..005, DD-131): desenha por cima da janela do minimapa (a) o evento global em
## aviso/execução — marcador no ponto onde ele está e, se o ponto está do outro lado do planeta, uma seta presa à borda
## apontando para onde olhar —, com a direção em que os grandes eventos andam, e (b) os bônus disponíveis, piscando.
## O mapa é o próprio planeta renderizado pela MinimapCamera; aqui só entram marcas 2D (nada é criado no mundo 3D).
## A conta de projeção é estática e pura (`project`), para o teste conferir sem tela.
## DD-185 (Passo 145): também desenha os JOGADORES em campo (ponto na cor da civilização, o seu com anel branco que pulsa e seta de rumo;
## rival do outro lado do planeta vira seta presa à borda) e as BASES (losango na cor do dono). Aberto, o minimapa escreve o nome do rival.
## ponytail: marcas redesenhadas a cada quadro (poucas dezenas de pontos); sem ícones por tipo de evento.

const EVENT_COLOR := Color(1.0, 0.35, 0.25)
const MARK_RADIUS := 7.0
const HEADING_LENGTH := 16.0
const MAX_BONUS_MARKS := 24
const PLAYER_DOT := 4.5
const RIVAL_DOT := 3.5
const BASE_SIZE := 3.5
const EDGE_LIMIT := 0.9   # marca além deste raio da janela (outro lado do planeta, ou fora do zoom) vira seta presa à borda
const OUTLINE_COLOR := Color(0.04, 0.05, 0.1, 0.9)

const WARNING_HOLD_MSEC := 1500   # o aviso é repetido a cada segundo; se parar de chegar (o meteoro não tem "fim"), some

var event_name := ""        # último aviso recebido (o nome só vem no aviso)
var event_seconds := 0      # contagem do aviso; 0 = em execução

var _active := false
var _warning_until := 0

var _camera: Camera3D
var _expanded := false   # minimapa aberto: o nome do rival aparece ao lado do ponto


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera = get_node_or_null("../SubViewport/MinimapCamera") as Camera3D
	EventBus.minimap_held.connect(func(held: bool): _expanded = held)
	EventBus.global_event_warning.connect(func(event: String, seconds: int):
		event_name = event
		event_seconds = seconds
		_warning_until = Time.get_ticks_msec() + WARNING_HOLD_MSEC)
	EventBus.global_event_active_changed.connect(func(active: bool):
		event_seconds = 0
		_warning_until = 0   # o aviso acabou: começou (ou terminou) a execução
		_active = active)
	EventBus.match_ended.connect(func():
		_active = false
		_warning_until = 0)


## Há aviso ou execução de evento global em curso?
func event_live() -> bool:
	return _active or Time.get_ticks_msec() < _warning_until


## Onde fica, na janela quadrada do minimapa, o ponto do planeta na direção `direction` (unitária, a partir do centro).
## A câmera está no eixo `cam_dir` (unitário, centro → câmera) a `distance` do centro, com `right`/`up` da tela.
## Retorna {"pos": Vector2 em -1..1 (x p/ direita, y p/ baixo), "front": bool}. Do outro lado do horizonte a marca
## é presa à borda da silhueta do planeta, na direção lateral em que o ponto está.
static func project(direction: Vector3, cam_dir: Vector3, right: Vector3, up: Vector3, distance: float, radius: float, tan_half_fov: float) -> Dictionary:
	var toward := direction.dot(cam_dir)
	var lateral := Vector2(direction.dot(right), -direction.dot(up))
	if toward > radius / distance:
		var depth := distance - radius * toward
		return {"pos": lateral * radius / (depth * tan_half_fov), "front": true}
	var rim := radius / (sqrt(distance * distance - radius * radius) * tan_half_fov)
	var edge := lateral.normalized() if lateral.length() > 0.001 else Vector2.UP
	return {"pos": edge * rim, "front": false}


## A cor da marca de uma civilização: a cor do solo dela, com saturação e brilho mínimos para ler pequena sobre o planeta.
static func marker_color(base: Color) -> Color:
	return Color.from_hsv(base.h, maxf(base.s, 0.5), maxf(base.v, 0.9))


## `project` com os parâmetros da câmera num dicionário `view` {cam_dir, right, up, distance, radius, tan_half}.
static func project_in(direction: Vector3, view: Dictionary) -> Dictionary:
	return project(direction, view["cam_dir"], view["right"], view["up"], view["distance"], view["radius"], view["tan_half"])


## Bases e jogadores em campo, já projetados: [{kind "base"|"runner", id, name, color, player, pos (-1..1), front, heading}].
## `heading` = para onde o corredor anda na janela (Vector2 unitário; zero para base). Ordem: bases, rivais, o jogador por último (por cima).
func marks(view: Dictionary) -> Array:
	var center: Vector3 = Services.planet.center
	var out: Array = []
	for id: int in Services.home_bases.keys():
		out.append(_mark("base", id, (Services.home_bases[id]["position"] as Vector3) - center, Vector3.ZERO, view))
	var mine := {}
	for node in get_tree().get_nodes_in_group("runners"):
		var runner := node as PlanetRunner
		var civ: Civilization = runner.get_node_or_null("Civilization") as Civilization if runner != null else null
		if civ == null or not runner.is_active_in_field():
			continue
		var mark := _mark("runner", civ.id, runner.global_position - center, runner.forward, view)
		if mark["player"]:
			mine = mark
		else:
			out.append(mark)
	if not mine.is_empty():
		out.append(mine)
	return out


func _mark(kind: String, id: int, offset: Vector3, heading: Vector3, view: Dictionary) -> Dictionary:
	var dir := offset.normalized()
	var placed := project_in(dir, view)
	var pos: Vector2 = placed["pos"]
	var step := Vector2.ZERO
	if heading != Vector3.ZERO and placed["front"]:
		step = ((project_in((dir + heading * 0.15).normalized(), view)["pos"] as Vector2) - pos).normalized()
		if not step.is_finite():
			step = Vector2.ZERO
	var theme: PlanetTheme = Services.themes.theme_of(id) if Services.themes != null else null
	return {"kind": kind, "id": id, "name": theme.civilization_name if theme != null else "",
			"color": marker_color(theme.soil_base) if theme != null else Color.WHITE,
			"player": id == Civilization.PLAYER_ID, "pos": pos, "front": placed["front"], "heading": step}


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var planet := Services.planet
	if planet == null or _camera == null:
		return
	var offset := _camera.global_position - planet.center
	var distance := offset.length()
	if distance <= planet.radius:
		return
	var cam_dir := offset / distance
	var basis := _camera.global_basis
	var tan_half := tan(deg_to_rad(_camera.fov * 0.5))
	var half := size * 0.5
	var view := {"cam_dir": cam_dir, "right": basis.x, "up": basis.y, "distance": distance, "radius": planet.radius, "tan_half": tan_half}

	# Bônus: anel que pisca (só os do lado visível — do outro lado não há o que apontar)
	var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	var drawn := 0
	for node in get_tree().get_nodes_in_group("bonus_pickups"):
		if drawn >= MAX_BONUS_MARKS:
			break
		var spot := ((node as Node3D).global_position - planet.center).normalized()
		var placed := project(spot, cam_dir, basis.x, basis.y, distance, planet.radius, tan_half)
		if not placed["front"] or (placed["pos"] as Vector2).length() > 1.0:
			continue
		var color := _bonus_color(node)
		var at: Vector2 = half + (placed["pos"] as Vector2) * half
		draw_arc(at, 5.0 + 2.0 * blink, 0.0, TAU, 20, color, 2.0, true)
		draw_circle(at, 2.0, color)
		drawn += 1

	_draw_players(view, half, blink)

	# Evento global: marcador (ou seta na borda) + rumo + texto
	if not event_live():
		return
	for node in get_tree().get_nodes_in_group("minimap_events"):
		var focus: Dictionary = node.minimap_focus()
		if focus.is_empty():
			continue
		var placed := project(focus["direction"], cam_dir, basis.x, basis.y, distance, planet.radius, tan_half)
		var at: Vector2 = half + (placed["pos"] as Vector2).limit_length(1.0) * half
		if placed["front"]:
			draw_arc(at, MARK_RADIUS + 3.0 * blink, 0.0, TAU, 24, EVENT_COLOR, 2.5, true)
			draw_circle(at, 3.0, EVENT_COLOR)
			var heading: Vector3 = focus["heading"]
			if heading != Vector3.ZERO:
				var ahead := project((focus["direction"] + heading * 0.15).normalized(), cam_dir, basis.x, basis.y, distance, planet.radius, tan_half)
				var step: Vector2 = ((ahead["pos"] as Vector2) - (placed["pos"] as Vector2)).normalized()
				if step.is_finite():
					_arrow(at + step * (MARK_RADIUS + 2.0), step)
		else:
			_arrow(at, (placed["pos"] as Vector2).normalized())   # fora da vista: seta na borda, apontando para fora
	var font := ThemeDB.fallback_font
	var label := "%s %ds" % [event_name, event_seconds] if event_seconds > 0 else event_name
	draw_string(font, Vector2(4.0, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 11, EVENT_COLOR)


func _arrow(tip_from: Vector2, dir: Vector2, color := EVENT_COLOR) -> void:
	var side := dir.orthogonal()
	var tip := tip_from + dir * HEADING_LENGTH * 0.5
	draw_colored_polygon(PackedVector2Array([tip, tip_from - dir * 2.0 + side * 5.0, tip_from - dir * 2.0 - side * 5.0]), color)


# Bases (losango) e jogadores (ponto). O jogador: anel branco que pulsa + seta de rumo; rival fora da vista: seta colorida na borda.
func _draw_players(view: Dictionary, half: Vector2, blink: float) -> void:
	var font := ThemeDB.fallback_font
	for m: Dictionary in marks(view):
		var pos: Vector2 = m["pos"]
		var color: Color = m["color"]
		var is_player: bool = m["player"]
		var out_of_view: bool = not m["front"] or pos.length() > EDGE_LIMIT
		if m["kind"] == "base":
			if not out_of_view:
				_draw_base(half + pos * half, color, is_player)
		elif out_of_view:
			var dir := pos.normalized()
			_arrow(half + dir * EDGE_LIMIT * half, dir, color)
		else:
			var at: Vector2 = half + pos * half
			var dot := PLAYER_DOT if is_player else RIVAL_DOT
			draw_circle(at, dot + 1.5, Color.WHITE if is_player else OUTLINE_COLOR)
			draw_circle(at, dot, color)
			if is_player:
				draw_arc(at, dot + 4.0 + 2.0 * blink, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.5 + 0.4 * blink), 1.5, true)
			var step: Vector2 = m["heading"]
			if step != Vector2.ZERO:
				_arrow(at + step * (dot + 3.0), step, Color.WHITE if is_player else color)
			if _expanded and not is_player:
				var label_at := at + Vector2(dot + 4.0, 4.0)
				draw_string_outline(font, label_at, m["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, OUTLINE_COLOR)
				draw_string(font, label_at, m["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _draw_base(at: Vector2, color: Color, is_player: bool) -> void:
	var r := BASE_SIZE + (1.5 if is_player else 0.0)
	var diamond := PackedVector2Array([at + Vector2(0.0, -r), at + Vector2(r, 0.0), at + Vector2(0.0, r), at + Vector2(-r, 0.0)])
	draw_colored_polygon(diamond, color)
	diamond.append(diamond[0])
	draw_polyline(diamond, Color.WHITE if is_player else OUTLINE_COLOR, 1.5, true)


func _bonus_color(node: Node) -> Color:
	var shown := node.get_child(0) as MeshInstance3D if node.get_child_count() > 0 else null
	var material := shown.mesh.material as StandardMaterial3D if shown and shown.mesh else null
	return material.albedo_color if material else Color.WHITE
