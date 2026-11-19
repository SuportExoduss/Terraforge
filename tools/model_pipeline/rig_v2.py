import bpy, math, sys
from mathutils import Vector, Matrix, Euler

W = "D:/Terraforge_Godotrt/work_g01/"
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else W + "g01_rigged.glb"
bpy.ops.wm.open_mainfile(filepath=W + "g01_v2.blend")
elf = bpy.data.objects["Guardiao"]
CX = -0.035
me = elf.data
part_attr = me.attributes["part"]

# ---------- armadura
arm_data = bpy.data.armatures.new("Armature"); arm = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm; arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
def bone(name, head, tail, parent=None):
    b = eb.new(name); b.head = Vector(head); b.tail = Vector(tail)
    if parent: b.parent = eb[parent]
    return b
bone("Hips", (CX, 0, 0.30), (CX, 0, 0.38))
bone("Chest", (CX, 0, 0.38), (CX, 0, 0.60), "Hips")
bone("Head", (CX, -0.01, 0.60), (CX, -0.01, 0.98), "Chest")
bone("Cape", (CX, 0.10, 0.52), (CX, 0.12, 0.15), "Chest")
for s, sx in (("A", 1), ("B", -1)):
    x = CX + sx * 0.09
    bone("Thigh" + s, (x, -0.04, 0.30), (x, -0.04, 0.19), "Hips")
    bone("Shin" + s, (x, -0.04, 0.19), (x + sx * 0.02, -0.05, 0.04), "Thigh" + s)
    xa = CX + sx * 0.20
    bone("UpArm" + s, (xa, -0.03, 0.47), (xa, -0.03, 0.385), "Chest")
    bone("ForeArm" + s, (xa, -0.03, 0.385), (xa, -0.06, 0.28), "UpArm" + s)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------- pesos
STAFF = {1, 30, 50, 52, 32, 31, 36, 27, 26}
BOOTS = {5, 6, 47, 48, 56, 57, 38, 40, 64, 65, 71, 72}
PANTS = {12}
CAPE = {2, 11, 23}
SLEEVE = {14: "A", 15: "B"}
GLOVE = {8: "A", 9: "B"}
PAD = {76: "A", 77: "B"}
TABARD = {4, 59}
# centro (z) de cada peca, para classificar a cabeca
import bmesh
bm = bmesh.new(); bm.from_mesh(me)
part_l = bm.faces.layers.int.get("part")
vpart = {}; zs = {}
for f in bm.faces:
    for v in f.verts:
        vpart[v.index] = f[part_l]; zs.setdefault(f[part_l], []).append(v.co.z)
cz = {p: (min(l) + max(l)) / 2 for p, l in zs.items()}
vco = {v.index: v.co.copy() for v in bm.verts}
bm.free()

def sm(a, b, x):  # 0 em a, 1 em b (a pode ser > b)
    t = max(0.0, min(1.0, (x - a) / (b - a))); return t * t * (3 - 2 * t)

def side_of(co): return "A" if co.x > CX else "B"
def side_blend(co, w=0.03):  # peso do lado A (cruza o meio sem rasgar)
    return max(0.0, min(1.0, 0.5 + (co.x - CX) / (2 * w)))

def weights(i):
    if i not in vpart: return {"Chest": 1.0}   # vertice solto (sem face)
    p = vpart[i]; co = vco[i]; s = side_of(co)
    if p in STAFF: return {"Chest": 1.0}
    if p in BOOTS: return {"Shin" + s: 1.0}
    if p in GLOVE: return {"ForeArm" + GLOVE[p]: 1.0}
    if p in SLEEVE:
        t = sm(0.37, 0.42, co.z); return {"UpArm" + SLEEVE[p]: t, "ForeArm" + SLEEVE[p]: 1 - t}
    if p in PAD: return {"UpArm" + PAD[p]: 0.6, "Chest": 0.4}
    if p in PANTS:
        a = side_blend(co)
        hips = sm(0.24, 0.31, co.z); shin = sm(0.19, 0.15, co.z); thigh = 1 - hips - shin
        thigh = max(thigh, 0.0)
        return {"Hips": hips, "ThighA": thigh * a, "ThighB": thigh * (1 - a), "ShinA": shin * a, "ShinB": shin * (1 - a)}
    if p in CAPE:
        c = sm(0.52, 0.30, co.z); return {"Chest": 1 - c, "Cape": c}
    if cz[p] >= 0.62: return {"Head": 1.0}
    hips = sm(0.43, 0.33, co.z)
    w = {"Hips": hips, "Chest": 1 - hips}
    if p in TABARD:
        t = 0.5 * sm(0.30, 0.21, co.z); a = side_blend(co)
        w = {k: v * (1 - t) for k, v in w.items()}; w["ThighA"] = t * a; w["ThighB"] = t * (1 - a)
    return w

for b in arm_data.bones: elf.vertex_groups.new(name=b.name)
for i in range(len(me.vertices)):
    for name, wt in weights(i).items():
        if wt > 0.001: elf.vertex_groups[name].add([i], wt, 'REPLACE')
elf.parent = arm
mod = elf.modifiers.new("Armature", 'ARMATURE'); mod.object = arm

# ---------- animacao
fps = 30; N = 16
bpy.context.scene.render.fps = fps
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
act = bpy.data.actions.new("Correr"); arm.animation_data_create(); arm.animation_data.action = act
Rrest = {b.name: b.matrix_local.to_3x3() for b in arm_data.bones}
def rx(deg, z=0.0): return Euler((math.radians(deg), 0, math.radians(z)), 'XYZ').to_matrix()
def setrot(name, Rd):
    pb = arm.pose.bones[name]; R = Rrest[name]
    pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (R.inverted() @ Rd @ R).to_quaternion()
    pb.keyframe_insert("rotation_quaternion", frame=cur)
for k in range(N + 1):
    cur = k + 1; ph = 2 * math.pi * k / N
    sA = math.sin(ph); sB = -sA
    # quadris
    hb = arm.pose.bones["Hips"]; hb.location = Rrest["Hips"].inverted() @ Vector((0, 0, 0.014 * math.cos(2 * ph) - 0.007))
    hb.keyframe_insert("location", frame=cur)
    setrot("Hips", rx(9, 6 * sA))
    setrot("Chest", rx(4, -9 * sA))
    setrot("Head", rx(-9, 3 * sA))
    for s, sg in (("A", sA), ("B", sB)):
        setrot("Thigh" + s, rx(-30 * sg))
        setrot("Shin" + s, rx(10 + 42 * (0.5 + 0.5 * math.cos(ph + (0.5 if s == "A" else 0.5 + math.pi)))))
        setrot("UpArm" + s, rx(36 * sg))
        setrot("ForeArm" + s, rx(-48 - 10 * sg))
    setrot("Cape", rx(12 + 9 * math.sin(2 * ph + 0.9)))
bpy.ops.object.mode_set(mode='OBJECT')
for fc in act.fcurves:
    for kp in fc.keyframe_points: kp.interpolation = 'LINEAR' if False else 'BEZIER'
bpy.context.scene.frame_start = 1; bpy.context.scene.frame_end = N + 1

bpy.ops.object.select_all(action='DESELECT')
elf.select_set(True); arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, use_selection=True, export_apply=False,
                          export_animations=True, export_skins=True, export_image_format='JPEG', export_jpeg_quality=92,
                          export_materials='EXPORT', export_force_sampling=True)
print("EXPORTADO", OUT, "ossos", len(arm_data.bones))
