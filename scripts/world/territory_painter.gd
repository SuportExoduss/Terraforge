class_name TerritoryPainter
extends Node
## Pinta o território no planeta (porta do TerritoryPainter.cs). Filho do Planet.
## Duas imagens equirretangulares 1024x512: POSSE (rgb = cor do solo, a = cobertura) e IDS (R = dono).
## O shader planet_surface.gdshader lê as duas; aqui também mora get_elevation_at, a mesma conta do
## vértice do shader, para os pés do corredor acompanharem a camada de bioma que SOBE (DD-121).
## As células chegam do TerritoryMap (EventBus) de uma vez, mas são pintadas em fila, 300 por quadro:
## a conquista "escorre" pelo chão em vez de aparecer de golpe (DD-110).

const W := 1024
const H := 512
const BRUSH_PER_FRAME := 300
const UPLOAD_INTERVAL := 0.05
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
var _queue: Array = []           # [owner_id, PackedVector3Array, spacing, próximo índice]
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
	var budget := BRUSH_PER_FRAME
	while budget > 0 and not _queue.is_empty():
		budget -= _paint_chunk(_queue[0], budget)
		if _queue[0][3] >= (_queue[0][1] as PackedVector3Array).size():
			_queue.pop_front()
	_since_upload += delta
	if _dirty and _since_upload >= UPLOAD_INTERVAL:
		_upload_images()


## Pinta tudo que está na fila já (testes e telas de resultado).
func paint_all_now() -> void:
	while not _queue.is_empty():
		_paint_chunk(_queue[0], 1 << 30)
		_queue.pop_front()
	_upload_images()


func pending_cells() -> int:
	var n := 0
	for chunk in _queue:
		n += (chunk[1] as PackedVector3Array).size() - chunk[3]
	return n


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
	if not cells.is_empty():
		_queue.append([owner_id, cells, spacing, 0])


## Pinta até `budget` células do bloco e devolve quantas pintou.
func _paint_chunk(chunk: Array, budget: int) -> int:
	var owner_id: int = chunk[0]
	var cells: PackedVector3Array = chunk[1]
	var spacing: float = chunk[2]
	var from: int = chunk[3]
	var to := mini(from + budget, cells.size())
	var theme := Services.themes.theme_of(owner_id) if Services.themes != null else null
	var soil := theme.soil_base if theme != null else NEUTRAL_SOIL
	var own_color := Color(soil.r, soil.g, soil.b, 1.0)
	var id_color := Color(owner_id / 255.0, 0.0, 0.0, 1.0)
	var center := _planet.center
	for i in range(from, to):
		_stamp(((cells[i] - center)).normalized(), spacing * 1.05 / _planet.radius, own_color, id_color)
	chunk[3] = to
	_dirty = true
	return to - from


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
