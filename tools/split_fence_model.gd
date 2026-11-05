extends SceneTree
## Divide o CowboyFence.glb (estaca e corda são malhas separadas) em POSTE e ELO (DD-125).
## POSTE = estaca + a volta de corda em torno dela (rígido). ELO = a corda solta, alinhada reta e
## normalizada para 1 unidade em +Z (o jogo estica até a distância real entre os postes).
## Roda uma vez; os .res resultantes ficam versionados. Imprime medidas (link_height etc.) para conferir.
## Uso: godot_console --headless --path . -s res://tools/split_fence_model.gd

const SRC := "res://art/models/cowboy/CowboyFence.glb"
const OUT_POST := "res://art/models/cowboy/CowboyFencePost.res"
const OUT_LINK := "res://art/models/cowboy/CowboyFenceLink.res"
const CUT_Z := -0.24   # a volta de corda termina aqui; dali em diante é a corda solta (medido no GLB)


class Part:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var t := PackedFloat32Array()
	var i := PackedInt32Array()

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_TEX_UV] = uv
		if not t.is_empty():
			a[Mesh.ARRAY_TANGENT] = t
		a[Mesh.ARRAY_INDEX] = i
		return a

	func bounds() -> AABB:
		var box := AABB(v[0], Vector3.ZERO)
		for p in v:
			box = box.expand(p)
		return box


func _initialize() -> void:
	var root := (load(SRC) as PackedScene).instantiate() as Node3D
	var stake_mi := root.find_child("tripo_part_6", true, false) as MeshInstance3D
	var rope_mi := root.find_child("tripo_part_2", true, false) as MeshInstance3D
	var stake := _read(stake_mi, root)
	var rope := _read(rope_mi, root)
	var wrap := _pick(rope, false)
	var cord := _pick(rope, true)

	# Origem do poste = centro do pé da estaca (os elos usam o mesmo referencial).
	var sb := stake.bounds()
	var shift := Vector3(sb.get_center().x, sb.position.y, sb.get_center().z)
	for part in [stake, wrap, cord]:
		for k in (part as Part).v.size():
			(part as Part).v[k] -= shift

	# ELO: acha a reta da corda (x e y em função de z, mínimos quadrados) e endireita por ela.
	var cb := cord.bounds()
	var zmid := cb.get_center().z
	var length := cb.size.z
	var n := float(cord.v.size())
	var mean := Vector3.ZERO
	for p in cord.v:
		mean += p / n
	var sxx := 0.0
	var sxz := 0.0
	var syz := 0.0
	for p in cord.v:
		sxx += (p.z - mean.z) * (p.z - mean.z)
		sxz += (p.z - mean.z) * (p.x - mean.x)
		syz += (p.z - mean.z) * (p.y - mean.y)
	var bx := sxz / sxx
	var by := syz / sxx
	var ax := mean.x - bx * mean.z
	var ay := mean.y - by * mean.z
	var rx := 0.0
	var ry := 0.0
	for k in cord.v.size():
		var p := cord.v[k]
		var q := Vector3(p.x - (ax + bx * p.z), p.y - (ay + by * p.z), (p.z - zmid) / length)
		rx = maxf(rx, absf(q.x))
		ry = maxf(ry, absf(q.y))
		cord.v[k] = q
		var nn := cord.n[k]   # a escala em Z (1/length) muda a normal para (x, y, z*length)
		cord.n[k] = Vector3(nn.x, nn.y, nn.z * length).normalized()
		if not cord.t.is_empty():
			var tg := Vector3(cord.t[k * 4], cord.t[k * 4 + 1], cord.t[k * 4 + 2] / length).normalized()
			cord.t[k * 4] = tg.x
			cord.t[k * 4 + 1] = tg.y
			cord.t[k * 4 + 2] = tg.z

	var post_mesh := ArrayMesh.new()
	post_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stake.arrays())
	post_mesh.surface_set_material(0, _mat(stake_mi))
	post_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wrap.arrays())
	post_mesh.surface_set_material(1, _mat(rope_mi))
	var link_mesh := ArrayMesh.new()
	link_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cord.arrays())
	link_mesh.surface_set_material(0, _mat(rope_mi))
	var e1 := ResourceSaver.save(post_mesh, OUT_POST)
	var e2 := ResourceSaver.save(link_mesh, OUT_LINK)

	print("poste: estaca %d tris + volta %d tris | tamanho=%s | pé em y=0, centro x/z=0" % [
			stake.i.size() / 3, wrap.i.size() / 3, post_mesh.get_aabb().size])
	print("elo: %d tris | comprimento original=%.3f (vira 1.0) | ancorado do poste: z[%.3f..%.3f] em coordenadas do poste" % [
			cord.i.size() / 3, length, cb.position.z, cb.end.z])
	print("elo: link_height (altura da corda no meio, em unidades do poste) = %.3f | inclinação x=%.3f y=%.3f | resíduo máx x=%.3f y=%.3f (≈raio da corda)" % [
			ay + by * zmid, bx, by, rx, ry])
	print("salvou: poste=%s elo=%s" % [error_string(e1), error_string(e2)])
	root.free()
	quit(0 if e1 == OK and e2 == OK else 1)


# Lê a malha já no referencial da raiz do GLB (acumula os nós entre a malha e a raiz).
func _read(mi: MeshInstance3D, root: Node3D) -> Part:
	var xf := Transform3D.IDENTITY
	var node: Node = mi
	while node != root:
		xf = (node as Node3D).transform * xf
		node = node.get_parent()
	var a := mi.mesh.surface_get_arrays(0)
	var src_v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var src_t: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var p := Part.new()
	for k in src_v.size():
		p.v.append(xf * src_v[k])
		p.n.append((xf.basis * src_n[k]).normalized())
		p.uv.append(src_uv[k])
		if not src_t.is_empty():
			var tg := xf.basis * Vector3(src_t[k * 4], src_t[k * 4 + 1], src_t[k * 4 + 2])
			p.t.append_array(PackedFloat32Array([tg.x, tg.y, tg.z, src_t[k * 4 + 3]]))
	p.i = a[Mesh.ARRAY_INDEX]
	print("%s: transform acumulado origem=%s base=%s" % [mi.name, xf.origin, xf.basis.get_euler() * (180.0 / PI)])
	return p


# Triângulos da corda solta (algum vértice além do CUT_Z) ou da volta (todos aquém), reindexados.
func _pick(src: Part, cord: bool) -> Part:
	var out := Part.new()
	var remap := {}
	for t in src.i.size() / 3:
		var tri: Array[int] = [src.i[t * 3], src.i[t * 3 + 1], src.i[t * 3 + 2]]
		if tri.any(func(k: int) -> bool: return src.v[k].z > CUT_Z) != cord:
			continue
		for k in tri:
			if not remap.has(k):
				remap[k] = out.v.size()
				out.v.append(src.v[k])
				out.n.append(src.n[k])
				out.uv.append(src.uv[k])
				if not src.t.is_empty():
					out.t.append_array(src.t.slice(k * 4, k * 4 + 4))
			out.i.append(remap[k])
	return out


func _mat(mi: MeshInstance3D) -> Material:
	var m := mi.get_active_material(0)
	return m.duplicate() if m != null else null
