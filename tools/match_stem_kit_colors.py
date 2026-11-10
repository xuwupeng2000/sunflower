"""Blender: match new stem-kit albedo averages to the original sampled stalks."""
import bpy,json,numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'assets/tripo/animated/profiles.json';profiles=json.loads(p.read_text())
def mean_color(path):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(ROOT/path.removeprefix('res://')))
 values=[]
 for o in bpy.context.scene.objects:
  if o.type!='MESH' or not o.data.uv_layers.active:continue
  for mi,m in enumerate(o.data.materials):
   if not m or not m.use_nodes:continue
   bs=m.node_tree.nodes.get('Principled BSDF');image=None
   if bs:
    socket=bs.inputs['Base Color']
    if socket.links and socket.links[0].from_node.type=='TEX_IMAGE':image=socket.links[0].from_node.image
   if image is None:continue
   pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels);pixels=pixels.reshape((-1,4))
   w,h=image.size
   faces=[f for f in o.data.polygons if f.material_index==mi and abs(f.normal.z)<.8]
   for f in faces[::max(1,len(faces)//500)]:
    uv=sum((o.data.uv_layers.active.data[i].uv for i in f.loop_indices),__import__('mathutils').Vector((0,0)))/len(f.loop_indices)
    x=int(uv.x*w)%w;y=int(uv.y*h)%h;values.append(pixels[y*w+x,:3].copy())
 if not values:raise RuntimeError('No albedo samples '+path)
 return np.median(np.asarray(values),axis=0)
for name in ['clivia','sunflower-new']:
 for spec in profiles[name]['stems']:
  if 'variants' not in spec:continue
  original=mean_color(spec['sample']);tints=[]
  for path in spec['variants']:
   kit=mean_color(path);tint=np.clip(original/np.maximum(kit,.02),.35,1.4);tints.append([float(c) for c in tint]);print('TINT',name,path,tints[-1],flush=True)
  spec['variant_tints']=tints
p.write_text(json.dumps(profiles,indent=2))
