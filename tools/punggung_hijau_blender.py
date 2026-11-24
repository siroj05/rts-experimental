"""Generate the editable 1 m terrain, reference trees and scenario markers from prepared map inputs."""
from pathlib import Path
import math
import sys
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from punggung_hijau_layout import DEPTH,HIGH,IRON,LOW,NAME,POINTS,STARTS,STEM,WIDTH,forest

root=Path(__file__).resolve().parents[1]
work=root/'.cache'/STEM
art=root.parent/'blender-assets/peta'/STEM
art.mkdir(exist_ok=True,parents=True)

def export_height():
    """Export the edited grid in the current .blend, preserving Recoil row order."""
    ob=bpy.data.objects.get('Verdant Ridge | 1024 × 768 m')
    if ob is None or ob.type!='MESH' or len(ob.data.vertices)!=1025*769:
        raise ValueError('Open the 1025 × 769 Verdant Ridge source mesh first.')
    xyz=np.empty((769,1025,3),dtype=np.float32)
    ob.data.vertices.foreach_get('co',xyz.ravel())
    transform=np.asarray(ob.matrix_world)
    xyz=xyz@transform[:3,:3].T+transform[:3,3]
    z,x=np.ogrid[0:769,0:1025]
    if not (np.allclose(xyz[:,:,0],x-512,atol=.001) and np.allclose(xyz[:,:,1],384-z,atol=.001)):
        raise ValueError('Recoil requires a regular one-metre XY grid.')
    height=xyz[:,:,2]*8
    if not (height.min()>=LOW and height.max()<=HIGH):
        raise ValueError('Height exceeds the configured SMF range.')
    work.mkdir(parents=True,exist_ok=True)
    np.rint((height-LOW)*65535/(HIGH-LOW)).astype('<u2').tofile(work/'tinggi.raw')

if '--export-height' in sys.argv:
    export_height()
    print('Saved Verdant Ridge heightfield')
    sys.exit(0)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
cols,rows=WIDTH//8+1,DEPTH//8+1
h=np.fromfile(work/'tinggi.raw','<u2').reshape(rows,cols).astype('float32')*((HIGH-LOW)/(8*65535))+LOW/8
z,x=np.indices(h.shape,dtype=np.float32)
vertices=np.stack((x-512,384-z,h),axis=-1)
idx=np.arange(cols*rows,dtype=np.int32).reshape(rows,cols)[:-1,:-1].ravel()
faces=np.stack((idx,idx+cols,idx+cols+1,idx+1),axis=1)
mesh=bpy.data.meshes.new('Terrain 1 m')
mesh.vertices.add(h.size)
mesh.vertices.foreach_set('co',vertices.ravel())
mesh.loops.add(faces.size)
mesh.loops.foreach_set('vertex_index',faces.ravel())
mesh.polygons.add(len(idx))
mesh.polygons.foreach_set('loop_start',np.arange(0,faces.size,4,dtype='int32'))
mesh.polygons.foreach_set('use_smooth',np.ones(len(idx),bool))
mesh.update(calc_edges=True)
uv=mesh.uv_layers.new(name='Albedo')
uv.data.foreach_set('uv',np.stack((x/1024,1-z/768),axis=-1).reshape(-1,2)[faces.ravel()].ravel())
ground=bpy.data.objects.new('Verdant Ridge | 1024 × 768 m',mesh)
scene.collection.objects.link(ground)

def mat(name,color):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=m.diffuse_color
    bs.inputs['Roughness'].default_value=.89
    return m,bs

soil,bs=mat('Prairie • shale • alluvium',(.11,.19,.07))
image=soil.node_tree.nodes.new('ShaderNodeTexImage')
image.image=bpy.data.images.load(str(work/'warna.png'))
image.image.pack()
soil.node_tree.links.new(image.outputs['Color'],bs.inputs['Base Color'])
mesh.materials.append(soil)
bpy.ops.mesh.primitive_plane_add(size=2)
water=bpy.context.object
water.name='Creek | waterline'
water.scale=(512,384,1)
water.data.materials.append(mat('Creek',(.051,.13,.095))[0])

def group(name):
    c=bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c

def position(a,b):
    return (a/8-512,384-b/8,h[round(b/8),round(a/8)])

woods=group('Fir silhouettes | engine feature positions')
proxies=[]
for k in range(4):
    verts=[]
    faces=[]
    for r,alt in ((.16,.1),(1.3,1.3),(.61,2.5),(1.02,2.65),(.43,3.65),(.72,3.72),(.04,5.8)):
        for i in range(8):
            theta=i*math.tau/8
            verts.append((r*math.cos(theta),r*math.sin(theta),alt*(1+k*.10)))
    for j in range(6):
        for i in range(8):
            a=j*8+i
            b=j*8+(i+1)%8
            faces.append((a,b,b+8,a+8))
    m=bpy.data.meshes.new(f'Fir proxy {k+1}')
    m.from_pydata(verts,[],faces)
    m.materials.append(mat(f'Needles {k+1}',(.033+k*.004,.075+k*.007,.040))[0])
    proxies.append(m)
for i,(px,pz,k,angle) in enumerate(forest()):
    o=bpy.data.objects.new(f'Fir {i+1}',proxies[k])
    woods.objects.link(o)
    o.location=position(px,pz)
    o.rotation_euler.z=angle*math.tau/65536
for name,points,radius in (('HQ',STARTS,8),('Control',POINTS,11),('Iron',IRON,2)):
    c=group(name)
    for i,(px,pz) in enumerate(points):
        label='ABCD'[i] if name=='Control' else str(i+1)
        o=bpy.data.objects.new(name+' '+label,None)
        c.objects.link(o)
        o.location=position(px,pz)
        o.empty_display_type='CIRCLE'
        o.empty_display_size=radius
        o.show_name=True
bpy.ops.object.light_add(type='SUN')
sun=bpy.context.object
sun.data.energy=2.7
sun.data.color=(1,.93,.83)
sun.rotation_euler=Vector((.67,.45,-.59)).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('Cool daylight')
scene.world.color=(.32,.39,.46)
bpy.ops.object.camera_add(location=(0,-665,905))
cam=bpy.context.object
cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=1170
cam.data.clip_end=2600
scene.camera=cam
scene.render.resolution_x=1536
scene.render.resolution_y=960
scene.render.resolution_percentage=100
scene.render.engine='CYCLES'
scene.cycles.samples=6
scene.cycles.use_denoising=True
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active
        space.clip_end=3000
        space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
        space.region_3d.view_distance=1180
        space.region_3d.view_perspective='ORTHO'
        space.shading.color_type='TEXTURE'
        space.overlay.show_overlays=False
bpy.context.preferences.filepaths.save_version=0
scene.render.filepath=str(art/(STEM+'-rts.png'))
bpy.ops.wm.save_as_mainfile(filepath=str(art/(STEM+'.blend')),compress=True)
bpy.ops.render.render(write_still=True)

