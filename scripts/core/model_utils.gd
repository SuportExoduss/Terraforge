class_name ModelUtils
extends RefCounted
## Utilitários para modelos importados (GLB).


## Caixa envolvente EXATA (pelos vértices, pose de repouso) de todos os MeshInstance3D sob `root`,
## no espaço local de `root`. Usa vértices porque transformar a AABB de um nó rotacionado a infla.
## `root` precisa estar dentro da árvore.
static func local_aabb(root: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var p := xf * v
				lo = lo.min(p)
				hi = hi.max(p)
	return AABB(lo, hi - lo) if lo.x != INF else AABB()
