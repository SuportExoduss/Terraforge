extends SceneTree
## Teste de fumaça do Passo 110 (DD-150, kit de bioma procedural): (1) os 5 kits têm os 12 slots, cada um uma malha com altura > 0,
## orçamento de triângulos (barato para MultiMesh no celular), faces voltadas para fora (giro coerente com a normal) e cor por vértice;
## (2) kit desconhecido / slot fora da faixa = null; (3) o PackedScene é guardado (2ª chamada devolve o mesmo); (4) a ficha de bioma
## usa o kit onde não há modelo de arte (e o modelo de arte VENCE o kit; o morto cai no vivo escurecido); (5) civilização com kit é jogável;
## (6) as 5 civilizações sem arte têm ficha com kit e cores próprias (solo diferente entre si).
## Uso: godot_console --headless --path . -s res://tools/smoke_biome_kit.gd

const BiomeKit := preload("res://scripts/world/biome_kit.gd")
const MAX_TRIANGLES := 700       # por modelo: 720 slots no mapa, vários modelos por categoria, tudo em MultiMesh
const MAX_TOTAL := 5000          # um kit inteiro (12 modelos)


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("FALHOU: ", msg)
		quit(1)
	return ok


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var seen_soil := {}
	for kit: String in BiomeKit.KITS:
		var total := 0
		var colors := {}
		for slot in BiomeKit.SLOTS:
			var scene: PackedScene = BiomeKit.scene(kit, slot)
			if not _check(scene != null, "%s/E%02d: sem cena" % [kit, slot + 1]): return
			var root := scene.instantiate() as Node3D
			var meshes := root.find_children("*", "MeshInstance3D", true, false)
			if not _check(meshes.size() == 1, "%s/E%02d: espero 1 MeshInstance3D (achei %d)" % [kit, slot + 1, meshes.size()]): return
			var mesh: ArrayMesh = (meshes[0] as MeshInstance3D).mesh
			var aabb := mesh.get_aabb()
			if not _check(aabb.size.y > 0.2 and aabb.size.x > 0.05 and aabb.size.z > 0.05, "%s/E%02d: malha sem volume (%s)" % [kit, slot + 1, aabb]): return
			var tris := 0
			for s in mesh.get_surface_count():
				if not _check(mesh.surface_get_material(s) != null, "%s/E%02d: superfície sem material" % [kit, slot + 1]): return
				var arrays := mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				if not _check(verts.size() % 3 == 0 and verts.size() == normals.size() and verts.size() == cols.size(), "%s/E%02d: arrays incoerentes" % [kit, slot + 1]): return
				tris += verts.size() / 3
				for t in verts.size() / 3:
					var a := verts[t * 3]
					var cross := (verts[t * 3 + 1] - a).cross(verts[t * 3 + 2] - a)
					# giro horário (frente no Godot): o produto vetorial aponta CONTRA a normal
					if not _check(cross.dot(normals[t * 3]) < 0.0, "%s/E%02d: triângulo %d com giro invertido" % [kit, slot + 1, t]): return
					colors[cols[t * 3].to_html(false)] = true
			if not _check(tris >= 4 and tris <= MAX_TRIANGLES, "%s/E%02d: %d triângulos (orçamento %d)" % [kit, slot + 1, tris, MAX_TRIANGLES]): return
			total += tris
			root.free()
		if not _check(total <= MAX_TOTAL, "%s: %d triângulos no kit (orçamento %d)" % [kit, total, MAX_TOTAL]): return
		if not _check(colors.size() >= 12, "%s: poucas cores (%d): o kit parece sem vida" % [kit, colors.size()]): return
		if not _check(BiomeKit.scene(kit, 3) == BiomeKit.scene(kit, 3), "%s: a cena deve ser guardada em cache" % kit): return
		print("kit %-9s 12 slots, %4d triângulos, %2d cores" % [kit, total, colors.size()])
	if not _check(BiomeKit.scene("nao_existe", 0) == null and BiomeKit.scene("alien", 12) == null and BiomeKit.scene("alien", -1) == null and not BiomeKit.has_kit(""), "kit ou slot inválido = null"): return

	# Ficha de bioma: kit onde falta arte; arte vence o kit; morto = vivo escurecido (null)
	var theme := PlanetTheme.new()
	theme.procedural_kit = "alien"
	if not _check(theme.slot_model(0, false) == BiomeKit.scene("alien", 0), "ficha com kit usa o modelo do kit"): return
	if not _check(theme.slot_model(0, true) == null, "o gêmeo morto sem arte é null (o sistema escurece o vivo)"): return
	var art := PackedScene.new()
	theme.e01_vegetacao_alta = art
	if not _check(theme.slot_model(0, false) == art and theme.slot_model(1, false) == BiomeKit.scene("alien", 1), "o modelo de arte vence o kit, slot a slot"): return
	theme.procedural_kit = ""
	if not _check(theme.slot_model(1, false) == null, "sem kit e sem arte o slot fica vazio"): return

	# Civilizações: as 5 sem arte têm kit e solos próprios; o Velho Oeste (arte) continua como estava
	var catalog = load("res://scripts/core/civilization_catalog.gd")
	var civs_with_kit := 0
	for civ in range(1, 7):
		var t: PlanetTheme = load("res://art/themes/theme_civ%d.tres" % civ)
		if not _check(t != null, "falta a ficha theme_civ%d.tres" % civ): return
		if t.procedural_kit != "":
			civs_with_kit += 1
			if not _check(BiomeKit.has_kit(t.procedural_kit), "civ%d: kit '%s' não existe" % [civ, t.procedural_kit]): return
			seen_soil[t.soil_base.to_html(false)] = civ
	if not _check(civs_with_kit == 5, "5 civilizações com kit (achei %d)" % civs_with_kit): return
	if not _check(seen_soil.size() == 5, "cada kit com um solo diferente"): return
	for civ in range(1, 7):
		if not _check(catalog.is_playable(civ), "civ%d deve ser jogável" % civ): return
	print("OK")
	quit(0)
