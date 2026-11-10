import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'assets/tripo/sunflower-new.glb'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in obs:
 bpy.context.view_layer.objects.active=o;bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 # Face groups retain UV loops. Narrow central stem is separate from foliage.
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,1.04),plane_no=(0,0,1),dist=.000001)
 bm.to_mesh(o.data);bm.free();o.data.update()
 groups={'Bloom':[],'Stalk':[]};candidates=set();edges={}
 for f in o.data.polygons:
  c=f.center
  if c.z>1.03999:groups['Bloom'].append(f.index)
  elif math.hypot(c.x+.007,c.y-.017)<.055:groups['Stalk'].append(f.index)
  else:
   candidates.add(f.index)
   for e in f.edge_keys:edges.setdefault(e,[]).append(f.index)
 neighbors={i:set() for i in candidates}
 for fs in edges.values():
  for i in fs:neighbors[i].update(fs)
 count=0
 while candidates:
  seed=candidates.pop();component={seed};pending=[seed]
  while pending:
   for n in neighbors[pending.pop()]:
    if n in candidates:candidates.remove(n);component.add(n);pending.append(n)
  if len(component)<25:groups['Stalk']+=list(component)
  else:
   zs=[o.data.vertices[v].co.z for i in component for v in o.data.polygons[i].vertices]
   if max(zs)>1.039:groups['Bloom']+=list(component)
   else:groups['Leaf'+str(count)]=list(component);count+=1
 anchors={}
 for key,fs in groups.items():
  mesh=o.data.copy();piece=bpy.data.objects.new(key,mesh);bpy.context.collection.objects.link(piece)
  bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table();keep=set(fs)
  bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],context='FACES');bm.to_mesh(mesh);bm.free()
  if key.startswith('Leaf'):
   a=min(mesh.vertices,key=lambda v:math.hypot(v.co.x+.007,v.co.y-.017)).co
   anchors[key]=[a.x,a.z,-a.y]
  print('PART',key,len(mesh.polygons),[round(min(v.co.z for v in mesh.vertices),3),round(max(v.co.z for v in mesh.vertices),3)])
 bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.export_scene.gltf(filepath=str(root/'assets/tripo/animated/sunflower-maturity.glb'),export_format='GLB')

(root/'assets/tripo/animated/sunflower-maturity-leaves.json').write_text(json.dumps(anchors,indent=2))
