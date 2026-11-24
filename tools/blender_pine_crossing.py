"""Build Pine Crossing in Blender. Pass the staging and source directories after --."""
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pine_crossing_layout import DEPTH, HIGH, IRON, LOW, POINTS, STARTS, WIDTH, terrain, trees

work, art = map(Path, sys.argv[sys.argv.index("--")+1:])
art.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'


def collection(name):
    result = bpy.data.collections.new(name)
    scene.collection.children.link(result)
    return result


def mesh(name, vertices, faces, group):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    group.objects.link(obj)
    return obj


def world(x,z,h):
    return ((x-WIDTH/2)/8,(DEPTH/2-z)/8,h/8)


ground = collection("Terrain")
props = collection("Vegetasi pratinjau Recoil")
markers = collection("Penanda untuk ekspor Recoil")
studio = collection("Kamera dan pencahayaan")
cols, rows = WIDTH//8+1, DEPTH//8+1
zz, xx = np.ogrid[0:DEPTH+1:8,0:WIDTH+1:8]
heights = terrain(xx, zz)[0]
vertices = [world(x*8,z*8,heights[z,x]) for z in range(rows) for x in range(cols)]
faces = [(i,i+cols,i+cols+1,i+1) for i in range(cols*(rows-1)) if i%cols != cols-1]
ground_obj = mesh("Pine Crossing | heightmap 1 m", vertices, faces, ground)
data = ground_obj.data
uv = data.uv_layers.new()
coords = np.empty((len(vertices),2), np.float32)
coords[:,0] = (np.asarray(vertices)[:,0]*8+WIDTH/2)/WIDTH
coords[:,1] = (np.asarray(vertices)[:,1]*8+DEPTH/2)/DEPTH
indices = np.empty(len(data.loops), dtype=np.int32)
data.loops.foreach_get("vertex_index", indices)
uv.data.foreach_set("uv", coords[indices].ravel())
data.polygons.foreach_set("use_smooth", np.ones(len(faces), dtype=bool))


def material(name, rgba, roughness):
    m=bpy.data.materials.new(name)
    m.diffuse_color=rgba
    m.use_nodes=True
    bs=m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value=rgba
    bs.inputs["Roughness"].default_value=roughness
    return m


soil = material("Padang pinus · albedo 4096 × 3072", (.13,.19,.08,1), .88)
ground_obj.data.materials.append(soil)
nodes, links = soil.node_tree.nodes, soil.node_tree.links
image = nodes.new("ShaderNodeTexImage")
image.image = bpy.data.images.load(str(work/"warna.png"))
image.image.pack()
links.new(image.outputs["Color"], nodes.get("Principled BSDF").inputs["Base Color"])
detail = nodes.new("ShaderNodeTexNoise")
detail.inputs["Scale"].default_value = 1400
bump = nodes.new("ShaderNodeBump")
bump.inputs["Distance"].default_value = .24
bump.inputs["Strength"].default_value = .28
links.new(detail.outputs["Fac"], bump.inputs["Height"])
links.new(bump.outputs["Normal"], nodes.get("Principled BSDF").inputs["Normal"])
water=mesh("Sungai · permukaan air", [world(0,DEPTH,0),world(WIDTH,DEPTH,0),world(WIDTH,0,0),world(0,0,0)], [(0,1,2,3)], ground)
water.data.materials.append(material("Air biru batu",(.046,.155,.168,1),.29))

pine = []
for kind in range(4):
    v=[(0,0,6+kind*.42)]
    f=[]
    for radius, high in ((.27,.3),(1.47,1.45),(.73,2.54),(1.13,2.75),(.59,3.59),(.80,3.76),(.37,4.5)):
        for i in range(9):
            a=i*math.tau/9+high
            r=radius*(1+.12*math.cos(i*3+kind))
            v.append((r*math.cos(a),r*math.sin(a),high+math.sin(i*4)*.1))
    for j in range(6):
        for i in range(9):
            a,b=1+j*9+i,1+j*9+(i+1)%9
            f.append((a,b,b+9,a+9))
    f.extend((55+i,55+(i+1)%9,0) for i in range(9))
    variant=mesh(f"Pinus {kind+1}",v,f,props)
    variant.data.materials.append(material(f"Jarum pinus {kind+1}",(.041+kind*.005,.081+kind*.008,.031+kind*.004,1),.82))
    pine.append(variant.data)
    bpy.data.objects.remove(variant, do_unlink=True)


def marker(name, x, z, size):
    obj=bpy.data.objects.new(name,None)
    markers.objects.link(obj)
    obj.location=world(x,z,terrain(x,z)[0])
    obj.empty_display_type='CIRCLE'
    obj.empty_display_size=size
    obj.show_name=True
    return obj


exports={"starts":[],"points":[],"iron":[],"trees":[]}
for key, values, label, size in (("starts",STARTS,"HQ",6),("points",POINTS,"Point",8),("iron",IRON,"Iron",1.9)):
    for i,(x,z) in enumerate(values):
        obj=marker(f"{label} {'ABCD'[i] if key=='points' else i+1}",x,z,size)
        exports[key].append([round(WIDTH/2+obj.location.x*8),round(DEPTH/2-obj.location.y*8)])
for i,(x,z,kind,rot) in enumerate(trees()):
    obj=bpy.data.objects.new(f"TreeType{kind}.{i:03}",pine[kind])
    props.objects.link(obj)
    obj.location=world(x,z,terrain(x,z)[0])
    obj.rotation_euler.z=rot*math.tau/65536
    exports["trees"].append([x,z,kind,rot])

heights=np.asarray(vertices,dtype=np.float32)[:,2]*8
assert heights.min()>=LOW and heights.max()<=HIGH
np.rint((heights-LOW)*(65535/(HIGH-LOW))).astype("<u2").tofile(work/"tinggi.raw")
(work/"layout.json").write_text(json.dumps(exports),encoding="utf-8")

world_data=bpy.data.worlds.new("Langit siang")
scene.world=world_data
world_data.use_nodes=True
world_data.node_tree.nodes.get("Background").inputs[0].default_value=(.62,.75,.91,1)
world_data.node_tree.nodes.get("Background").inputs[1].default_value=.46
sun=bpy.data.lights.new("Matahari",'SUN')
sun.energy=2.35
sun.color=(1,.96,.86)
sun_obj=bpy.data.objects.new("Matahari",sun)
studio.objects.link(sun_obj)
sun_obj.rotation_euler=(.46,-.5,-.35)
cam_data=bpy.data.cameras.new("Kamera RTS")
cam_data.type='ORTHO'
cam_data.ortho_scale=608
cam=bpy.data.objects.new("Kamera RTS",cam_data)
studio.objects.link(cam)
cam.location=(.0,-360,475)
cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.clip_end=1900
scene.camera=cam
scene.render.engine='CYCLES'
scene.cycles.samples=12
scene.cycles.use_denoising=True
scene.render.resolution_x=1460
scene.render.resolution_y=950
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.clip_end=2200
            area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            area.spaces.active.region_3d.view_distance=625
            area.spaces.active.region_3d.view_perspective='ORTHO'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(art/"pine-crossing-4v4.blend"))
scene.render.filepath=str(art/"pine-crossing-rts.png")
bpy.ops.render.render(write_still=True)
