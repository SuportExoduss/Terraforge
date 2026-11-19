import bpy, numpy as np
W = "D:/Terraforge_Godotrt/work_g01/"
bpy.ops.wm.open_mainfile(filepath=W + "g01_built.blend")
elf = bpy.data.objects["Guardiao"]; me = elf.data
d = np.load(W + "mesh3.npz"); UV = d["UV"]; T = d["T"]
assert len(T) == len(me.polygons)
uvl = me.uv_layers["UVMap"] if "UVMap" in me.uv_layers else me.uv_layers[0]
buf = np.zeros((len(me.loops), 2), np.float32)
for i, p in enumerate(me.polygons):
    assert tuple(p.vertices) == tuple(T[i]), i
    for k, l in enumerate(p.loop_indices): buf[l] = UV[i, k]
uvl.data.foreach_set("uv", buf.ravel())
mat = me.materials[0]; nt = mat.node_tree
tex = [n for n in nt.nodes if n.type == 'TEX_IMAGE'][0]
img = bpy.data.images.load(W + "atlas_v2.png"); img.name = "Guardiao_atlas_v2"; img.pack()
old = tex.image; tex.image = img
if old: bpy.data.images.remove(old)
bpy.ops.wm.save_as_mainfile(filepath=W + "g01_v2.blend", compress=False)
print("APLICADO", len(T))
