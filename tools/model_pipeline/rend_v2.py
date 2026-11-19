import bpy, sys, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mins=Vector((1e9,)*3); maxs=Vector((-1e9,)*3)
for o in bpy.data.objects:
    if o.type=='MESH':
        for v in o.bound_box:
            w=o.matrix_world@Vector(v)
            for i in range(3): mins[i]=min(mins[i],w[i]); maxs[i]=max(maxs[i],w[i])
c=(mins+maxs)/2; size=maxs-mins
sc=bpy.context.scene
sc.render.engine='BLENDER_WORKBENCH'
sc.render.resolution_x=640; sc.render.resolution_y=800
sc.display.shading.light='FLAT'
sc.display.shading.color_type='TEXTURE'
sc.view_settings.view_transform='Standard'
sc.display.shading.background_type='VIEWPORT'; sc.display.shading.background_color=(0.8,0.8,0.8)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=max(size)*1.15
views=(("f",Vector((0,-1,0.0))),("34",Vector((-0.7,-0.7,0.35))),("lado",Vector((1,0,0.0))),("costas34",Vector((0.6,0.75,0.5))),("cima",Vector((0,0.4,1.0))))
for name,d in views:
    d=d.normalized(); cam.location=c+d*5
    cam.rotation_euler=(-d).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=out+"_"+name+".png"
    bpy.ops.render.render(write_still=True)
print("RENDER OK")
