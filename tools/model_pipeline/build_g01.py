import bpy, bmesh, sys, json, zlib, struct, math
import numpy as np
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree

W = "D:/Terraforge_Godotrt/work_g01/"
SRC = "C:/Users/andre/Desktop/modelos/03_Floresta/G01/elf archer 3d model.glb"
OUT = W + "g01_static.glb"
RATIO = float(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else 0.36

V = json.load(open(W + "views.json")); VIEWS = V["views"]; AW, AH, PAL = V["AW"], V["AH"], V["PAL"]
atlas = np.load(W + "atlas_base.npy")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
print("PARTES", len(meshes))

# --- achata hierarquia, decima cada peca, marca a peca por face
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
for o in meshes:
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
total_before = sum(len(o.data.polygons) for o in meshes)
for o in meshes:
    n = int(o.name.split("_")[-1])
    nt = len(o.data.polygons)
    a = o.data.attributes.new("part", 'INT', 'FACE'); a.data.foreach_set("value", [n] * nt)
    r = min(1.0, max(RATIO, 40.0 / max(nt, 1)))
    if r < 1.0:
        m = o.modifiers.new("dec", 'DECIMATE'); m.ratio = r; m.use_collapse_triangulate = True
        with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
            bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
elf = bpy.context.view_layer.objects.active; elf.name = "Guardiao"; elf.data.name = "Guardiao"
for o in list(bpy.data.objects):
    if o.type != 'MESH': bpy.data.objects.remove(o)

bm = bmesh.new(); bm.from_mesh(elf.data)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.faces.ensure_lookup_table()
print("TRIS", total_before, "->", len(bm.faces))
part_l = bm.faces.layers.int.get("part")
uvl = bm.loops.layers.uv.new("UVMap")
bvh = BVHTree.FromBMesh(bm)

# --- escolhe a vista de cada triangulo
def to_uv(v, co):
    h = v["s"] * (co.x if v["axis"] == "x" else co.y)
    rx = v["ax"] * h + v["bx"]; ry = v["by"] - v["ay"] * co.z
    px = v["slot_x"] + (rx - v["cx0"]) * v["k"]; py = (ry - v["cy0"]) * v["k"]
    px = min(max(px, v["slot_x"] + 0.5), v["slot_x"] + v["slot_w"] - 0.5)
    py = min(max(py, 0.5), v["slot_h"] - 0.5)
    return px, py

def samp(px, py):
    return atlas[min(int(py), AH - 1), min(int(px), AW - 1)].astype(float)

bias = {"F": 1.1}
assign = {}   # face index -> view index
colors = {}   # parte -> lista de cores amostradas (so da frente: a mais fiel)
samples = {}  # face index -> cor amostrada
cent_part = {}
for f in bm.faces:
    n = f.normal; c = f.calc_center_median(); p = f[part_l]
    cent_part.setdefault(p, []).append(c)
    best = None
    for vi, v in enumerate(VIEWS):
        D = Vector(v["D"]); fac = n.dot(D)
        if fac < 0.4: continue
        hit = bvh.ray_cast(c + n * 0.002, D)
        if hit[0] is not None: continue
        sc = fac * bias.get(v["name"], 1.0)
        if best is None or sc > best[0]: best = (sc, vi, fac)
    if best:
        assign[f.index] = best[1]
        v = VIEWS[best[1]]
        uvs = [to_uv(v, l.vert.co) for l in f.loops]
        cx = sum(u[0] for u in uvs) / 3; cy = sum(u[1] for u in uvs) / 3
        col = samp(cx, cy); samples[f.index] = col
        if best[2] >= 0.5: colors.setdefault(p, []).append(col)
        for l, (px, py) in zip(f.loops, uvs):
            l[uvl].uv = (px / AW, 1.0 - py / AH)
print("faces com vista", len(assign), "de", len(bm.faces))

# --- cor de cada peca (mediana), pecas sem amostra herdam da vizinha mais proxima
part_color = {}
for p, lst in colors.items():
    if len(lst) >= 3: part_color[p] = np.median(np.array(lst), axis=0)
# costas/lados desalinhados: cor muito fora da mediana da peca vira a cor da peca (palette)
OUT_D = 85.0
dropped = 0
for f in bm.faces:
    i = f.index
    if i in assign and VIEWS[assign[i]]["name"] != "F" and f[part_l] in part_color:
        if np.linalg.norm(samples[i] - part_color[f[part_l]]) > OUT_D:
            del assign[i]; dropped += 1
print("faces fora da cor da peca (viram paleta)", dropped)
cent = {p: sum(cs, Vector()) / len(cs) for p, cs in cent_part.items()}
for p in cent_part:
    if p in part_color: continue
    cands = sorted(part_color, key=lambda q: (cent[q] - cent[p]).length)
    part_color[p] = part_color[cands[0]] if cands else np.array([100., 120., 80.])
# paleta: celulas de 16x16 na faixa de baixo
cell = {}
for i, p in enumerate(sorted(part_color)):
    cell[p] = i
    x0 = i * 16
    atlas[AH - PAL:AH, x0:x0 + 16] = np.clip(part_color[p], 0, 255).astype(np.uint8)
for f in bm.faces:
    if f.index in assign: continue
    i = cell[f[part_l]]
    u = (i * 16 + 8) / AW; vv = 1.0 - (AH - PAL / 2) / AH
    for l in f.loops: l[uvl].uv = (u, vv)
bm.to_mesh(elf.data); bm.free()

# --- png do atlas
def write_png(path, arr):
    h, w, _ = arr.shape
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
write_png(W + "atlas_final.png", atlas)

# --- material
with bpy.context.temp_override(object=elf, active_object=elf, selected_objects=[elf]):
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(55))
mat = bpy.data.materials.new("Guardiao"); mat.use_nodes = True
nt = mat.node_tree; bsdf = nt.nodes["Principled BSDF"]
img = bpy.data.images.load(W + "atlas_final.png"); img.name = "Guardiao_atlas"
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = 'Linear'
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.85
bsdf.inputs["Metallic"].default_value = 0.0
elf.data.materials.clear(); elf.data.materials.append(mat)
img.pack()
bpy.ops.wm.save_as_mainfile(filepath=W + "g01_built.blend", compress=False)   # com o atributo 'part' (usado no rig)
elf.data.attributes.remove(elf.data.attributes["part"]) if "part" in elf.data.attributes else None

bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, export_apply=False, export_animations=False,
                          export_texcoords=True, export_normals=True, export_materials='EXPORT',
                          export_image_format='JPEG', export_jpeg_quality=92)
print("EXPORTADO", OUT)
