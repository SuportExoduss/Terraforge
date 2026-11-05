extends SceneTree
## Extrai o POSTE do CowboyTrail.glb (a cerca era poste+corda num modelo só; agora são dois: poste + elo).
## Corta os triângulos do lado do poste (x <= CUT_X), recentra no pé do poste e salva um ArrayMesh.
## Roda uma vez; o resultado (CowboyTrailPost.res) fica versionado. Imprime as medidas para conferir.
## Uso: godot_console --headless --path . -s res://tools/split_trail_model.gd

const SRC := "res://art/models/cowboy/CowboyTrail.glb"
const OUT := "res://art/models/cowboy/CowboyTrailPost.res"
const CUT_X := -0.2355   # o poste vai até x=-0.236; a corda começa logo depois (medido no GLB)


func _initialize() -> void:
	var m := (load(SRC) as PackedScene).instantiate() as Node3D
	var mi := m.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(mi.get_parent() == m, "a malha deveria ser filha direta da raiz do GLB")
	var xf := mi.transform   # o deslocamento do nó da malha dentro do GLB (a medição do CUT_X já o inclui)
	var arrays := mi.mesh.surface_get_arrays(0)
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if src_i.is_empty():
		src_i.resize(src_v.size())
		for k in src_v.size():
			src_i[k] = k

	var remap := {}
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var index := PackedInt32Array()
	for t in src_i.size() / 3:
		var tri: Array[int] = [src_i[t * 3], src_i[t * 3 + 1], src_i[t * 3 + 2]]
		if tri.any(func(k: int) -> bool: return (xf * src_v[k]).x > CUT_X):
			continue
		for k in tri:
			if not remap.has(k):
				remap[k] = verts.size()
				verts.append(xf * src_v[k])
				normals.append((xf.basis * src_n[k]).normalized())
				uvs.append(src_uv[k])
				if not src_t.is_empty():
					var tg := xf.basis * Vector3(src_t[k * 4], src_t[k * 4 + 1], src_t[k * 4 + 2])
					tangents.append_array(PackedFloat32Array([tg.x, tg.y, tg.z, src_t[k * 4 + 3]]))
			index.append(remap[k])

	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var shift := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)   # origem = centro do pé do poste
	for k in verts.size():
		verts[k] -= shift

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	if not tangents.is_empty():
		out[Mesh.ARRAY_TANGENT] = tangents
	out[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var mat := mi.get_active_material(0)
	mesh.surface_set_material(0, mat.duplicate() if mat != null else null)
	var err := ResourceSaver.save(mesh, OUT)
	print("poste: %d de %d vértices, %d de %d triângulos | tamanho=%s | material=%s albedo=%s normal=%s | salvou=%s" % [
			verts.size(), src_v.size(), index.size() / 3, src_i.size() / 3, hi - lo, mat,
			(mat as BaseMaterial3D).albedo_texture.resource_path if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null else "-",
			(mat as BaseMaterial3D).normal_texture.resource_path if mat is BaseMaterial3D and (mat as BaseMaterial3D).normal_texture != null else "-",
			error_string(err)])
	m.free()
	quit(0 if err == OK else 1)
