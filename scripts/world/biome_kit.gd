extends RefCounted
## Kit de bioma PROCEDURAL (Passo 110, DD-150): os 12 slots de ambiente (E01-E12) de uma civilização, desenhados em código
## (low-poly de faces chapadas, cor por vértice, sem arquivo de arte). Serve às 5 civilizações que ainda não têm modelos
## (Alien, Floresta Encantada, Skate City, Piratas, Reino do Gelo): cada uma ganha cara própria e fica jogável. Quando o
## André/Tripo entregar o modelo de um slot, ele entra na ficha PlanetTheme (e00..e12) e VENCE o kit, slot a slot.
## Cada modelo é UMA malha (2 superfícies: iluminada e "acesa" = sem sombreamento, para cristais, lâmpadas e neon) dentro de
## um PackedScene, no formato que o EnvironmentSlotSystem já consome (ele alinha o pé pela caixa e reescala pela altura do slot).
## Sem class_name de propósito (use `const BiomeKit := preload("res://scripts/world/biome_kit.gd")`).

const KITS := ["alien", "floresta", "skate", "piratas", "gelo"]
const SLOTS := 12
const WHITE := Color(0.96, 0.98, 1.0)

static var _cache := {}        # "kit/slot" -> PackedScene
static var _mats := {}         # "solid" / "lit" -> material compartilhado


static func has_kit(kit: String) -> bool:
	return KITS.has(kit)


## O modelo do slot `slot` (0 = E01 ... 11 = E12) do kit, ou null se o kit/slot não existe.
static func scene(kit: String, slot: int) -> PackedScene:
	if not KITS.has(kit) or slot < 0 or slot >= SLOTS:
		return null
	var key := "%s/%d" % [kit, slot]
	if not _cache.has(key):
		var builder := B.new()
		(_recipes(kit)[slot] as Callable).call(builder)
		_cache[key] = _pack(builder.finish(_material(false), _material(true)))
	return _cache[key]


static func _pack(mesh: ArrayMesh) -> PackedScene:
	var root := Node3D.new()
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	root.add_child(inst)
	inst.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


static func _material(lit: bool) -> StandardMaterial3D:
	var key := "lit" if lit else "solid"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.92
		if lit:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # "aceso": a cor do vértice sem luz nem sombra (some a escuridão da noite)
		_mats[key] = m
	return _mats[key]


# Posição + giro (yaw em Y, pitch em X, roll em Z).
static func _t(x := 0.0, y := 0.0, z := 0.0, yaw := 0.0, pitch := 0.0, roll := 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), Vector3(x, y, z))


# ---------------------------------------------------------------------------------------------------------------------
# O construtor de malha: triângulos com normal chapada e cor por vértice. O giro dos triângulos é corrigido sozinho (a face
# da frente no Godot é a de giro horário visto de fora), então as formas abaixo não precisam se preocupar com a ordem.
# ---------------------------------------------------------------------------------------------------------------------
class B:
	var _solid := SurfaceTool.new()
	var _lit := SurfaceTool.new()
	var _n_solid := 0
	var _n_lit := 0

	func _init() -> void:
		_solid.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lit.begin(Mesh.PRIMITIVE_TRIANGLES)

	func triangles() -> int:
		return _n_solid + _n_lit

	func finish(solid_material: Material, lit_material: Material) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if _n_solid > 0:
			_solid.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, solid_material)
		if _n_lit > 0:
			_lit.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, lit_material)
		return mesh

	func tri(a: Vector3, b: Vector3, c: Vector3, center: Vector3, col: Color, lit: bool) -> void:
		var cross := (b - a).cross(c - a)
		if cross.length_squared() < 0.000001:
			return
		if cross.dot((a + b + c) / 3.0 - center) > 0.0:   # (b-a)x(c-a) apontando para fora = giro anti-horário: inverte
			var t := b
			b = c
			c = t
			cross = -cross
		var n := -cross.normalized()
		var st := _lit if lit else _solid
		for p: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(p)
		if lit:
			_n_lit += 1
		else:
			_n_solid += 1

	## Tronco de cone de `sides` lados, base em y=0 (r1 = 0 vira cone). Serve de cone, cilindro, prisma, disco e telhado.
	func frustum(xf: Transform3D, r0: float, r1: float, h: float, sides: int, col: Color, lit := false) -> void:
		var c := xf * Vector3(0.0, h * 0.5, 0.0)
		var bot: Array[Vector3] = []
		var top: Array[Vector3] = []
		for i in sides:
			var a := TAU * i / sides
			bot.append(xf * Vector3(cos(a) * r0, 0.0, sin(a) * r0))
			top.append(xf * Vector3(cos(a) * r1, h, sin(a) * r1))
		var b0 := xf * Vector3.ZERO
		var t0 := xf * Vector3(0.0, h, 0.0)
		for i in sides:
			var j := (i + 1) % sides
			tri(bot[i], bot[j], top[j], c, col, lit)
			tri(b0, bot[j], bot[i], c, col, lit)
			if r1 > 0.001:
				tri(bot[i], top[j], top[i], c, col, lit)
				tri(t0, top[j], top[i], c, col, lit)

	## Elipsoide de poucas faces centrado na origem de `xf`.
	func ball(xf: Transform3D, rx: float, ry: float, rz: float, col: Color, lit := false, segs := 6) -> void:
		var lat := [[-1.0, 0.0], [-0.707, 0.707], [0.0, 1.0], [0.707, 0.707], [1.0, 0.0]]   # [altura, raio] de cada anel
		var center := xf * Vector3.ZERO
		var rows: Array = []
		for k in lat.size():
			var row: Array[Vector3] = []
			if lat[k][1] == 0.0:
				row.append(xf * Vector3(0.0, ry * lat[k][0], 0.0))
			else:
				for i in segs:
					var a := TAU * i / segs
					row.append(xf * Vector3(cos(a) * rx * lat[k][1], ry * lat[k][0], sin(a) * rz * lat[k][1]))
			rows.append(row)
		for k in lat.size() - 1:
			var lo: Array = rows[k]
			var hi: Array = rows[k + 1]
			for i in segs:
				var j := (i + 1) % segs
				if lo.size() == 1:
					tri(lo[0], hi[j], hi[i], center, col, lit)
				elif hi.size() == 1:
					tri(lo[i], lo[j], hi[0], center, col, lit)
				else:
					tri(lo[i], lo[j], hi[i], center, col, lit)
					tri(lo[j], hi[j], hi[i], center, col, lit)

	## Caixa com a base em y=0, centrada em X/Z.
	func box(xf: Transform3D, w: float, h: float, d: float, col: Color, lit := false) -> void:
		var p: Array[Vector3] = []
		for y: float in [0.0, h]:
			for sx: float in [-0.5, 0.5]:
				for sz: float in [-0.5, 0.5]:
					p.append(xf * Vector3(sx * w, y, sz * d))
		var c := xf * Vector3(0.0, h * 0.5, 0.0)
		for f: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			tri(p[f[0]], p[f[1]], p[f[2]], c, col, lit)
			tri(p[f[0]], p[f[2]], p[f[3]], c, col, lit)

	## Pedra: icosaedro com os vértices sacudidos (semente) e achatado em Y; cada face com um tom um pouco diferente.
	func rock(xf: Transform3D, r: float, flat: float, rng_seed: int, col: Color) -> void:
		var g := 1.618034
		var raw: Array[Vector3] = [Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0), Vector3(0, -1, g), Vector3(0, 1, g),
				Vector3(0, -1, -g), Vector3(0, 1, -g), Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1)]
		var rng := RandomNumberGenerator.new()
		rng.seed = rng_seed
		var p: Array[Vector3] = []
		for v in raw:
			var n := v.normalized() * r * rng.randf_range(0.72, 1.12)
			n.y *= flat
			p.append(xf * n)
		var c := xf * Vector3.ZERO
		for f: Array in [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
				[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]:
			tri(p[f[0]], p[f[1]], p[f[2]], c, col.darkened(rng.randf() * 0.2), false)


# ---------------------------------------------------------------------------------------------------------------------
# Arquétipos: o mesmo desenho serve a vários biomas, só mudam as cores e os parâmetros (cada kit é uma tabela de 12 linhas).
# ---------------------------------------------------------------------------------------------------------------------
static func _stalk(b: B, stem: Color, bulb: Color) -> void:   # caule alto com bulbos acesos
	b.frustum(_t(), 0.12, 0.06, 1.7, 5, stem)
	b.ball(_t(0.0, 1.85), 0.34, 0.3, 0.34, bulb, true)
	b.ball(_t(0.22, 1.25, 0.05), 0.16, 0.14, 0.16, bulb, true)
	b.ball(_t(-0.2, 0.9, -0.08), 0.13, 0.12, 0.13, bulb, true)


static func _tree_round(b: B, trunk: Color, leaf: Color) -> void:
	b.frustum(_t(), 0.15, 0.1, 0.95, 5, trunk)
	b.ball(_t(0.0, 1.35), 0.7, 0.6, 0.7, leaf)
	b.ball(_t(0.38, 1.05, 0.15), 0.42, 0.36, 0.42, leaf.lightened(0.12))
	b.ball(_t(-0.3, 1.7, -0.1), 0.4, 0.34, 0.4, leaf.darkened(0.08))


static func _pine(b: B, trunk: Color, leaf: Color, tiers: int, frost: float, lit: bool) -> void:   # pinheiro de cones empilhados
	b.frustum(_t(), 0.12, 0.1, 0.5, 5, trunk)
	for k in tiers:
		b.frustum(_t(0.0, 0.35 + k * 0.5), 0.64 - 0.12 * k, 0.0, 0.85, 6, leaf.lerp(WHITE, frost * (0.35 + 0.65 * k / float(tiers))), lit)


static func _palm(b: B, trunk: Color, leaf: Color) -> void:
	var lean := _t(0.0, 0.0, 0.0, 0.0, 0.0, -0.14)
	b.frustum(lean, 0.13, 0.08, 1.6, 5, trunk)
	var top := lean * Vector3(0.0, 1.6, 0.0)
	for k in 5:
		var base := Transform3D(Basis(Vector3.UP, TAU * k / 5.0), top)
		b.ball(base * Transform3D(Basis(Vector3.BACK, -0.5), Vector3(0.4, 0.02, 0.0)), 0.5, 0.06, 0.17, leaf.lightened(0.04 * k))
	b.ball(_t(top.x, top.y - 0.08, top.z), 0.12, 0.1, 0.12, trunk.darkened(0.3))


static func _mushroom(b: B, stem: Color, cap: Color, lit: bool, spots: bool) -> void:
	b.frustum(_t(), 0.2, 0.14, 0.7, 6, stem)
	b.ball(_t(0.0, 0.78), 0.62, 0.34, 0.62, cap, lit)
	if spots:
		b.ball(_t(0.22, 1.04, 0.1), 0.1, 0.06, 0.1, WHITE)
		b.ball(_t(-0.24, 1.0, -0.12), 0.08, 0.05, 0.08, WHITE)
		b.ball(_t(0.0, 1.1, -0.2), 0.07, 0.05, 0.07, WHITE)


static func _bush(b: B, col: Color, n: int, lit: bool) -> void:   # moitas / montinhos baixos
	for k in n:
		var a := TAU * k / n + 0.6
		b.ball(_t(cos(a) * 0.3, 0.2 + 0.03 * k, sin(a) * 0.3), 0.34, 0.26, 0.34, col.lightened(0.07 * k), lit)


static func _sprouts(b: B, col: Color, n: int, lit: bool) -> void:   # brotos / tentáculos: cones inclinados
	for k in n:
		var a := TAU * k / n
		b.frustum(_t(cos(a) * 0.2, 0.0, sin(a) * 0.2, 0.0, sin(a) * 0.3, -cos(a) * 0.3), 0.1, 0.0, 0.55 + 0.14 * k, 5, col.lightened(0.06 * k), lit)


static func _flowers(b: B, stem: Color, bloom: Color) -> void:
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var x := cos(a) * 0.22
		var z := sin(a) * 0.22
		var h := 0.5 + 0.12 * (k % 3)
		b.frustum(_t(x, 0.0, z), 0.03, 0.02, h, 4, stem)
		b.ball(_t(x, h + 0.05, z), 0.13, 0.1, 0.13, bloom.lightened(0.05 * k), true)


static func _crystals(b: B, col: Color, lit: bool, n: int) -> void:   # aglomerado de prismas com ponta
	for k in n:
		var a := TAU * k / n
		var off := 0.0 if k == 0 else 0.26
		var h := 1.0 if k == 0 else 0.55 + 0.1 * (k % 3)
		var xf := _t(cos(a) * off, 0.0, sin(a) * off, 0.0, sin(a) * 0.32 * minf(off * 4.0, 1.0), -cos(a) * 0.32 * minf(off * 4.0, 1.0))
		b.frustum(xf, 0.17, 0.15, h, 6, col, lit)
		b.frustum(xf * _t(0.0, h), 0.15, 0.0, h * 0.4, 6, col.lightened(0.18), lit)


static func _rock(b: B, col: Color, rng_seed: int) -> void:
	b.rock(_t(), 0.6, 0.78, rng_seed, col)


static func _hut(b: B, wall: Color, roof: Color) -> void:   # casinha: caixa + telhado piramidal + porta
	b.box(_t(), 0.9, 0.6, 0.9, wall)
	b.frustum(_t(0.0, 0.6, 0.0, PI / 4.0), 0.78, 0.0, 0.55, 4, roof)
	b.box(_t(0.0, 0.0, 0.45), 0.22, 0.36, 0.05, roof.darkened(0.45))


static func _dome(b: B, shell: Color, glow: Color, size: float) -> void:   # cúpula com base e faixa acesa
	b.frustum(_t(), 1.0 * size, 0.96 * size, 0.14, 8, shell.darkened(0.25))
	b.ball(_t(0.0, 0.14), 0.9 * size, 0.62 * size, 0.9 * size, shell, false, 8)
	b.frustum(_t(0.0, 0.14), 0.97 * size, 0.97 * size, 0.07, 8, glow, true)


static func _antenna(b: B, col: Color, glow: Color) -> void:
	b.frustum(_t(), 0.14, 0.07, 2.4, 4, col)
	b.frustum(_t(0.0, 1.2), 0.38, 0.3, 0.06, 6, col.lightened(0.1))
	b.ball(_t(0.0, 2.55), 0.16, 0.16, 0.16, glow, true)


static func _lamp(b: B, post: Color, head: Color) -> void:   # poste com lâmpada acesa
	b.frustum(_t(), 0.08, 0.05, 2.0, 5, post)
	b.frustum(_t(0.0, 1.95), 0.12, 0.22, 0.18, 6, head, true)


static func _egg(b: B, col: Color, lit: bool) -> void:
	b.frustum(_t(), 0.5, 0.45, 0.1, 7, col.darkened(0.4))
	b.ball(_t(0.0, 0.7), 0.42, 0.6, 0.42, col, lit, 7)


static func _obelisk(b: B, col: Color, glow: Color) -> void:   # marco: pilar de 4 lados, ponta e anel flutuantes acesos
	b.box(_t(), 1.5, 0.25, 1.5, col.darkened(0.3))
	b.frustum(_t(0.0, 0.25, 0.0, PI / 4.0), 0.78, 0.42, 2.4, 4, col)
	b.frustum(_t(0.0, 2.65, 0.0, PI / 4.0), 0.42, 0.0, 0.55, 4, glow, true)
	b.frustum(_t(0.0, 3.35), 0.6, 0.6, 0.07, 8, glow, true)


static func _tower(b: B, wall: Color, trim: Color, floors: int) -> void:   # prédio/torre em andares que afinam, com faixa acesa
	var w := 0.95
	for k in floors:
		b.box(_t(0.0, k * 0.62), w, 0.62, w, wall.lightened(0.04 * k))
		b.box(_t(0.0, k * 0.62 + 0.5), w + 0.07, 0.07, w + 0.07, trim, true)
		w -= 0.1
	b.frustum(_t(0.0, floors * 0.62, 0.0, PI / 4.0), w * 0.62, 0.0, 0.4, 4, trim.darkened(0.3))


static func _crate(b: B, col: Color, band: Color) -> void:
	b.box(_t(), 0.8, 0.62, 0.8, col)
	b.box(_t(0.0, 0.22), 0.85, 0.12, 0.85, band)
	b.box(_t(0.0, 0.62), 0.88, 0.05, 0.88, band.darkened(0.2))


static func _billboard(b: B, post: Color, panel: Color) -> void:
	b.frustum(_t(), 0.07, 0.07, 1.6, 4, post)
	b.box(_t(0.0, 1.3), 1.15, 0.62, 0.08, panel, true)
	b.box(_t(0.0, 1.26), 1.22, 0.05, 0.1, post)


static func _ramp(b: B, col: Color, accent: Color) -> void:
	var slab := _t(0.0, 0.1, 0.0, 0.0, 0.4)
	b.box(slab, 0.95, 0.12, 1.5, col)
	b.box(slab * _t(0.0, 0.12), 0.08, 0.04, 1.5, accent, true)
	b.box(_t(-0.36, 0.0, -0.5), 0.12, 0.3, 0.12, col.darkened(0.3))
	b.box(_t(0.36, 0.0, -0.5), 0.12, 0.3, 0.12, col.darkened(0.3))


static func _stack(b: B, col: Color, n: int) -> void:   # pneus empilhados
	for k in n:
		b.frustum(_t(0.04 * (k % 2), k * 0.17), 0.3, 0.3, 0.17, 8, col.lightened(0.05 * k))


static func _arch(b: B, col: Color, glow: Color) -> void:   # pórtico com viga acesa
	b.box(_t(-0.8), 0.24, 1.9, 0.24, col)
	b.box(_t(0.8), 0.24, 1.9, 0.24, col)
	b.box(_t(0.0, 1.9), 1.84, 0.24, 0.24, col)
	b.box(_t(0.0, 1.94), 1.5, 0.08, 0.28, glow, true)
	b.box(_t(0.0, -0.0), 2.1, 0.12, 0.5, col.darkened(0.3))


static func _mast(b: B, wood: Color, sail: Color) -> void:
	b.frustum(_t(), 0.08, 0.06, 2.3, 5, wood)
	b.box(_t(0.0, 0.7), 1.1, 1.15, 0.05, sail)
	b.box(_t(0.0, 0.62), 1.2, 0.06, 0.08, wood.darkened(0.2))
	b.box(_t(0.0, 1.85), 1.2, 0.06, 0.08, wood.darkened(0.2))


static func _barrel(b: B, wood: Color, band: Color) -> void:
	b.frustum(_t(), 0.3, 0.37, 0.32, 8, wood)
	b.frustum(_t(0.0, 0.32), 0.37, 0.3, 0.32, 8, wood)
	b.frustum(_t(0.0, 0.29), 0.375, 0.375, 0.06, 8, band)


static func _hull(b: B, wood: Color, sail: Color) -> void:   # casco encalhado, inclinado, com o mastro
	var lean := _t(0.0, 0.0, 0.0, 0.0, 0.0, 0.16)
	b.box(lean, 1.0, 0.6, 2.2, wood)
	b.box(lean * _t(0.0, 0.6), 0.84, 0.08, 2.0, wood.darkened(0.3))
	b.frustum(lean * _t(0.0, 0.68, 0.2), 0.07, 0.05, 1.8, 5, wood.darkened(0.25))
	b.box(lean * _t(0.0, 1.0, 0.2), 0.05, 0.9, 0.8, sail)


static func _cannon(b: B, iron: Color, wood: Color) -> void:
	b.box(_t(), 0.5, 0.2, 0.7, wood)
	b.frustum(_t(0.0, 0.38, -0.3, 0.0, PI / 2.0 - 0.15), 0.17, 0.12, 0.85, 7, iron)
	b.frustum(_t(-0.27, 0.2, 0.05, 0.0, 0.0, PI / 2.0), 0.2, 0.2, 0.06, 8, wood.darkened(0.3))
	b.frustum(_t(0.27, 0.2, 0.05, 0.0, 0.0, -PI / 2.0), 0.2, 0.2, 0.06, 8, wood.darkened(0.3))


static func _lighthouse(b: B, white: Color, red: Color) -> void:
	for k in 4:
		b.frustum(_t(0.0, k * 0.6), 0.5 - 0.07 * k, 0.43 - 0.07 * k, 0.6, 8, red if k % 2 == 1 else white)
	b.frustum(_t(0.0, 2.4), 0.5, 0.5, 0.08, 8, red.darkened(0.4))
	b.frustum(_t(0.0, 2.48), 0.24, 0.24, 0.36, 6, Color(1.0, 0.9, 0.4), true)
	b.frustum(_t(0.0, 2.84), 0.34, 0.0, 0.32, 6, red)


# ---------------------------------------------------------------------------------------------------------------------
# As tabelas dos kits: 12 linhas, na ordem E01..E12 (vegetação alta/média/baixa, rocha grande/pequena, estrutura pequena/média/
# grande, decoração natural/artificial, contêiner, marco).
# ---------------------------------------------------------------------------------------------------------------------
static func _recipes(kit: String) -> Array:
	match kit:
		"alien":
			var stem := Color(0.72, 0.62, 0.9)
			var violet := Color(0.45, 0.25, 0.68)
			var dark := Color(0.28, 0.2, 0.4)
			var teal := Color(0.2, 0.95, 0.8)
			var pink := Color(1.0, 0.3, 0.85)
			var metal := Color(0.55, 0.55, 0.68)
			return [_stalk.bind(stem, teal), _mushroom.bind(stem, pink, true, false), _sprouts.bind(teal, 4, true), _crystals.bind(pink, true, 5),
					_rock.bind(dark, 11), _dome.bind(metal, teal, 0.7), _antenna.bind(metal, teal), _dome.bind(violet, pink, 1.1),
					_sprouts.bind(violet, 3, true), _lamp.bind(metal, teal), _egg.bind(teal, true), _obelisk.bind(violet, pink)]
		"floresta":
			var trunk := Color(0.4, 0.27, 0.16)
			var leaf := Color(0.2, 0.62, 0.3)
			var pine := Color(0.12, 0.45, 0.3)
			var gold := Color(0.85, 0.65, 0.2)
			var moss := Color(0.42, 0.5, 0.42)
			var wood := Color(0.55, 0.36, 0.2)
			var roof := Color(0.7, 0.25, 0.22)
			return [_tree_round.bind(trunk, leaf), _pine.bind(trunk, pine, 3, 0.0, false), _bush.bind(leaf.lightened(0.1), 3, false),
					_rock.bind(moss, 21), _rock.bind(moss.lightened(0.1), 22), _mushroom.bind(Color(0.95, 0.92, 0.85), Color(0.9, 0.3, 0.4), false, true),
					_hut.bind(wood, roof), _tree_round.bind(trunk.darkened(0.2), gold), _flowers.bind(leaf, Color(1.0, 0.85, 0.3)),
					_lamp.bind(wood, Color(1.0, 0.85, 0.45)), _crate.bind(wood, trunk.darkened(0.2)), _pine.bind(trunk, Color(0.3, 0.9, 0.7), 5, 0.0, true)]
		"skate":
			var concrete := Color(0.62, 0.64, 0.7)
			var asphalt := Color(0.3, 0.32, 0.38)
			var brick := Color(0.65, 0.3, 0.25)
			var pink := Color(1.0, 0.2, 0.6)
			var cyan := Color(0.1, 0.9, 1.0)
			var yellow := Color(1.0, 0.8, 0.15)
			return [_lamp.bind(asphalt, pink), _ramp.bind(concrete, cyan), _crate.bind(concrete, yellow), _rock.bind(concrete, 31),
					_stack.bind(Color(0.16, 0.17, 0.2), 3), _hut.bind(brick, cyan.darkened(0.3)), _tower.bind(concrete, pink, 2),
					_tower.bind(asphalt.lightened(0.1), cyan, 4), _bush.bind(Color(0.25, 0.6, 0.35), 3, false), _billboard.bind(asphalt, pink),
					_crate.bind(Color(0.2, 0.5, 0.4), asphalt), _arch.bind(concrete, pink)]
		"piratas":
			var wood := Color(0.5, 0.32, 0.18)
			var dwood := Color(0.3, 0.2, 0.12)
			var leaf := Color(0.2, 0.6, 0.3)
			var cream := Color(0.95, 0.9, 0.78)
			var red := Color(0.75, 0.2, 0.18)
			var gold := Color(1.0, 0.8, 0.2)
			return [_palm.bind(dwood.lightened(0.15), leaf), _mast.bind(wood, cream), _barrel.bind(wood, dwood), _rock.bind(Color(0.45, 0.43, 0.42), 41),
					_rock.bind(Color(0.7, 0.62, 0.5), 42), _hut.bind(cream, red), _hut.bind(wood, dwood), _hull.bind(wood, cream),
					_bush.bind(Color(0.95, 0.45, 0.4), 4, false), _cannon.bind(Color(0.18, 0.18, 0.2), wood), _crate.bind(wood, gold),
					_lighthouse.bind(cream, red)]
		"gelo":
			var ice := Color(0.55, 0.85, 1.0)
			var snow := Color(0.92, 0.96, 1.0)
			var pine := Color(0.15, 0.42, 0.45)
			var trunk := Color(0.4, 0.28, 0.2)
			var wood := Color(0.5, 0.36, 0.26)
			return [_pine.bind(trunk, pine, 3, 0.55, false), _pine.bind(trunk, pine, 2, 0.6, false), _bush.bind(snow, 2, false),
					_rock.bind(Color(0.7, 0.84, 0.95), 51), _crystals.bind(ice, false, 3), _dome.bind(snow, Color(1.0, 0.8, 0.45), 0.7),
					_hut.bind(wood, snow), _tower.bind(ice, Color(0.4, 0.95, 1.0), 3), _crystals.bind(ice, true, 4), _lamp.bind(wood, Color(0.5, 0.8, 1.0)),
					_crate.bind(wood, snow), _obelisk.bind(ice, Color(0.4, 0.95, 1.0))]
	return []
