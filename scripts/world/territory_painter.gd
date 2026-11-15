class_name TerritoryPainter
extends Node
## Pinta o território no planeta (porta do TerritoryPainter.cs). Filho do Planet.
## Duas imagens equirretangulares 1024x512: POSSE (rgb = cor do solo, a = cobertura) e IDS (R = dono).
## O shader planet_surface.gdshader lê as duas; aqui também mora get_elevation_at, a mesma conta do
## vértice do shader, para os pés do corredor acompanharem a camada de bioma que SOBE (DD-121).
## As células chegam do TerritoryMap (EventBus) de uma vez, já em ORDEM DE ONDA (do território antigo para a borda
## nova, DD-127), e são pintadas em fila NO RITMO DO TEMPO: uma conquista dura 0,35–1,2 s, uma de cada vez
## (a ordem de pintura = a ordem lógica, então o estado final é sempre o mesmo). O "pé" da onda entra com alfa
## parcial num disco menor e o disco cheio vem logo atrás: o chão SOBE (a camada de bioma acompanha o alfa, DD-121).

const W := 1024
const H := 512
const WAVE_CELLS_PER_SECOND := 1100.0   # uma conquista de N células leva N/1100 s...
const WAVE_MIN_SECONDS := 0.35          # ...nunca menos que isto (conquista pequena ainda se vê)...
const WAVE_MAX_SECONDS := 1.2           # ...nem mais que isto (a transformação dura 0,8–1,2 s, DD-117)
const BACKLOG_SECONDS := 1.5            # fila acumulada além disto acelera, para a pintura não ficar atrasada
const LEAD_ALPHA := 0.45                # o pé da onda: o chão começa a subir com esta cobertura...
const LEAD_RADIUS := 0.75               # ...num disco desta fração do cheio...
const LAG_FRACTION := 0.2               # ...e o disco cheio chega depois desta fração da conquista
const UPLOAD_INTERVAL := 0.04
const ELEVATION_CROSS := 5       # texels do centro até cada braço da cruz de elevação
const MAX_CIVILIZATIONS := 16    # tamanho dos arrays do shader
const NEUTRAL_SOIL := Color(0.55, 0.42, 0.28)

var _planet: Planet
var _shader := preload("res://art/shaders/planet_surface.gdshader")
var _materials: Array[ShaderMaterial] = []
var _own := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
var _ids := Image.create_empty(W, H, false, Image.FORMAT_R8)
var _own_tex: ImageTexture
var _ids_tex: ImageTexture
var _queue: Array = []           # conquistas na ordem lógica: {owner, cells, spacing, lead, done, t, len}
var _dead := {}                  # id -> true (Death Biome, DD-122)
var _dirty := false
var _since_upload := 0.0


func _ready() -> void:
	_planet = get_parent() as Planet
	_planet.painter = self
	_own.fill(Color(0, 0, 0, 0))   # rgb 0 onde não há posse: o shader divide rgb por a
	_ids.fill(Color(0, 0, 0, 1))
	_own_tex = ImageTexture.create_from_image(_own)
	_ids_tex = ImageTexture.create_from_image(_ids)
	_convert_materials(_planet.get_node_or_null("Model"))
	_upload_kits()
	EventBus.territory_cells_claimed.connect(_on_cells_claimed)
	EventBus.civilization_eliminated.connect(_on_eliminated)


func _process(delta: float) -> void:
	var left := delta * maxf(1.0, _pending_seconds() / BACKLOG_SECONDS)   # fila longa = pintura mais rápida
	while left > 0.0 and not _queue.is_empty():
		var wave: Dictionary = _queue[0]
		var remaining: float = wave["len"] - wave["t"]
		var finished := left >= remaining
		wave["t"] = wave["len"] if finished else wave["t"] + left
		left -= minf(left, remaining)
		_advance(wave)
		if finished:
			_queue.pop_front()
	_since_upload += delta
	if _dirty and _since_upload >= UPLOAD_INTERVAL:
		_upload_images()


## Pinta tudo que está na fila já (testes e telas de resultado): só o disco cheio, na ordem lógica.
func paint_all_now() -> void:
	for wave in _queue:
		_stamp_range(wave, 1 << 30, false)
	_queue.clear()
	_upload_images()


## Células ainda sem o disco cheio.
func pending_cells() -> int:
	var n := 0
	for wave in _queue:
		n += (wave["cells"] as PackedVector3Array).size() - (wave["done"] as int)
	return n


func _pending_seconds() -> float:
	var seconds := 0.0
	for wave in _queue:
		seconds += (wave["len"] as float) - (wave["t"] as float)
	return seconds


## Quanto a camada de bioma levanta o chão nesta direção (DD-121): a mesma conta do vertex() do shader.
func get_elevation_at(direction: Vector3) -> float:
	var c := _texel_of(direction.normalized())
	var a := 2.0 * _alpha(c.x, c.y) + _alpha(c.x + ELEVATION_CROSS, c.y) + _alpha(c.x - ELEVATION_CROSS, c.y) \
			+ _alpha(c.x, c.y + ELEVATION_CROSS) + _alpha(c.x, c.y - ELEVATION_CROSS)
	if a <= 0.0:
		return 0.0
	var top := 0.0
	for off in [Vector2i(0, 0), Vector2i(ELEVATION_CROSS, 0), Vector2i(-ELEVATION_CROSS, 0), Vector2i(0, ELEVATION_CROSS), Vector2i(0, -ELEVATION_CROSS)]:
		top = maxf(top, _height_of(_owner_at(c.x + off.x, c.y + off.y)))
	return smoothstep(0.06, 0.9, a / 6.0) * top


func _texel_of(d: Vector3) -> Vector2i:
	var u := atan2(d.z, d.x) / TAU + 0.5
	var v := asin(clampf(d.y, -1.0, 1.0)) / PI + 0.5
	return Vector2i(floori(u * W), clampi(floori(v * H), 0, H - 1))


func _alpha(x: int, y: int) -> float:
	return _own.get_pixel(posmod(x, W), clampi(y, 0, H - 1)).a


func _owner_at(x: int, y: int) -> int:
	return roundi(_ids.get_pixel(posmod(x, W), clampi(y, 0, H - 1)).r * 255.0)


func _height_of(owner_id: int) -> float:
	var theme := Services.themes.theme_of(owner_id) if Services.themes != null else null
	return theme.ground_height if theme != null else 0.0


func _on_cells_claimed(owner_id: int, cells: PackedVector3Array, spacing: float) -> void:
	enqueue(owner_id, cells, spacing)


## Entra na fila de pintura (o replay repinta o planeta por aqui, na mesma ordem em que a partida o pintou).
func enqueue(owner_id: int, cells: PackedVector3Array, spacing: float) -> void:
	if cells.is_empty():
		return
	_queue.append({"owner": owner_id, "cells": cells, "spacing": spacing, "lead": 0, "done": 0, "t": 0.0,
			"len": clampf(cells.size() / WAVE_CELLS_PER_SECOND, WAVE_MIN_SECONDS, WAVE_MAX_SECONDS)})


## Apaga o território pintado e a fila (começo do replay). Não mexe em quem já morreu (_dead).
func clear() -> void:
	_queue.clear()
	_own.fill(Color(0, 0, 0, 0))
	_ids.fill(Color(0, 0, 0, 1))
	_upload_images()


## Avança a onda até o instante `t`: o pé (alfa parcial) vai na frente, o disco cheio chega LAG_FRACTION depois.
func _advance(wave: Dictionary) -> void:
	var n := (wave["cells"] as PackedVector3Array).size()
	var lag := ceili(n * LAG_FRACTION)
	var front: float = wave["t"] / wave["len"] * (n + lag)   # o pé chega a n quando o cheio ainda está lag atrás
	_stamp_range(wave, floori(front), true)
	_stamp_range(wave, floori(front) - lag, false)


## Carimba as células [já feitas, to) da onda; `lead` = o pé (parcial, menor), senão o disco cheio.
func _stamp_range(wave: Dictionary, to: int, lead: bool) -> void:
	var cells: PackedVector3Array = wave["cells"]
	var key := "lead" if lead else "done"
	var from: int = wave[key]
	to = clampi(to, 0, cells.size())
	if to <= from:
		return
	var owner_id: int = wave["owner"]
	var theme := Services.themes.theme_of(owner_id) if Services.themes != null else null
	var soil := theme.soil_base if theme != null else NEUTRAL_SOIL
	var a := LEAD_ALPHA if lead else 1.0
	var own_color := Color(soil.r * a, soil.g * a, soil.b * a, a)   # pré-multiplicado: o shader divide rgb por a
	var id_color := Color(owner_id / 255.0, 0.0, 0.0, 1.0)
	var radius: float = wave["spacing"] * 1.05 / _planet.radius * (LEAD_RADIUS if lead else 1.0)
	var center := _planet.center
	for i in range(from, to):
		_stamp((cells[i] - center).normalized(), radius, own_color, id_color)
	wave[key] = to
	_dirty = true


## Carimba uma elipse (o disco da célula, esticado em X pela curvatura da projeção) nas duas imagens.
func _stamp(d: Vector3, angular_radius: float, own_color: Color, id_color: Color) -> void:
	var cx := (atan2(d.z, d.x) / TAU + 0.5) * W
	var cy := (asin(clampf(d.y, -1.0, 1.0)) / PI + 0.5) * H
	var ry := maxf(angular_radius / PI * H, 0.5)
	var rx := maxf(angular_radius / TAU * W / maxf(0.05, sqrt(maxf(1.0 - d.y * d.y, 0.0))), 0.5)
	for y in range(floori(cy - ry), floori(cy + ry) + 1):
		if y < 0 or y >= H:
			continue
		var t := (y + 0.5 - cy) / ry
		if absf(t) > 1.0:
			continue
		var half := rx * sqrt(1.0 - t * t)
		_span(floori(cx - half), floori(cx + half), y, own_color, id_color)


## Preenche a faixa [x0, x1] da linha y nas duas imagens, dando a volta no meridiano da costura.
func _span(x0: int, x1: int, y: int, own_color: Color, id_color: Color) -> void:
	var n := x1 - x0 + 1
	if n >= W:
		x0 = 0
		n = W
	x0 = posmod(x0, W)
	var first := mini(n, W - x0)
	_own.fill_rect(Rect2i(x0, y, first, 1), own_color)
	_ids.fill_rect(Rect2i(x0, y, first, 1), id_color)
	if first < n:   # passou da borda direita: continua pela esquerda
		_own.fill_rect(Rect2i(0, y, n - first, 1), own_color)
		_ids.fill_rect(Rect2i(0, y, n - first, 1), id_color)


func _upload_images() -> void:
	_own_tex.update(_own)
	_ids_tex.update(_ids)
	_dirty = false
	_since_upload = 0.0


func _on_eliminated(owner_id: int) -> void:
	_dead[owner_id] = true
	_upload_kits()


## Troca o material do modelo pelo shader da superfície, herdando a textura e a cor do original.
func _convert_materials(model: Node) -> void:
	if model == null:
		return
	var converted := {}   # material original -> ShaderMaterial
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var source := mi.get_active_material(s)
			if not converted.has(source):
				var sm := ShaderMaterial.new()
				sm.shader = _shader
				if source is BaseMaterial3D:
					sm.set_shader_parameter("model_albedo", (source as BaseMaterial3D).albedo_texture)
					sm.set_shader_parameter("model_color", (source as BaseMaterial3D).albedo_color)
				sm.set_shader_parameter("ownership_map", _own_tex)
				sm.set_shader_parameter("id_map", _ids_tex)
				sm.set_shader_parameter("planet_center", _planet.center)
				sm.set_shader_parameter("terra_seed", randf() * 100.0)
				PlanetDef.apply_look(sm, Services.match_def)   # Passo 124: bioma do planeta escolhido (null = deserto)
				converted[source] = sm
				_materials.append(sm)
			mi.set_surface_override_material(s, converted[source])


## Empacota as fichas (índice = id - 1) nos arrays do shader e o atlas de pisos.
func _upload_kits() -> void:
	var params := PackedVector4Array()
	var tint := PackedVector4Array()
	var dead_tint := PackedVector4Array()
	var registry := Services.themes
	for i in MAX_CIVILIZATIONS:
		var theme := registry.theme_of(i + 1) if registry != null else null
		var atlas := registry.atlas if registry != null else null
		var slice := -1
		var dead_slice := -1
		if theme != null and atlas != null:
			slice = atlas.slice_of[i] if i < atlas.slice_of.size() else -1
			dead_slice = atlas.dead_slice_of[i] if i < atlas.dead_slice_of.size() else -1
		# cores de ficha são sRGB (como no inspetor); o shader trabalha em linear, como o Unity fazia
		var g := (theme.ground_tint if theme != null else Color(0.5, 0.5, 0.5)).srgb_to_linear()
		var d := (theme.dead_ground_tint if theme != null else Color(0.4, 0.38, 0.36)).srgb_to_linear()
		params.append(Vector4(theme.ground_tiling if theme != null else 16.0, slice,
				theme.ground_relief if theme != null else 0.0, theme.ground_height if theme != null else 0.0))
		tint.append(Vector4(g.r, g.g, g.b, 0.0 if _dead.has(i + 1) else 1.0))
		dead_tint.append(Vector4(d.r, d.g, d.b, dead_slice))
	for m in _materials:
		m.set_shader_parameter("ground_params", params)
		m.set_shader_parameter("ground_tint", tint)
		m.set_shader_parameter("dead_tint", dead_tint)
		if registry != null and registry.atlas != null:
			m.set_shader_parameter("ground_albedo", registry.atlas.albedo)
			m.set_shader_parameter("ground_normal", registry.atlas.normal)
