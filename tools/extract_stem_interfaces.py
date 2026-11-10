"""Extract actual stalk interface geometry and albedo from original approved plant meshes."""
import bpy,bmesh,json,math,bisect,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'assets/tripo/animated/profiles.json';profiles=json.loads(path.read_text());N=64
for name,profile in profiles.items():
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/tripo'/f'{name}.glb'))
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
 samples=[]
 for spec in profile['stems']:
  cx,cy,cut=spec['x'],-spec['z'],profile['cut_height'];radius=spec['radius'];levels=[]
  for dz in [-.025,0,.025]:
   z=cut+dz;points=[]
   for o in objects:
    image=None
    for mat in o.data.materials:
     if mat and mat.use_nodes:
      bs=mat.node_tree.nodes.get('Principled BSDF')
      if bs and bs.inputs['Base Color'].links:
       node=bs.inputs['Base Color'].links[0].from_node
       if node.type=='TEX_IMAGE':image=node.image;break
    if image is None:raise RuntimeError('Missing base texture '+name)
    pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels);pixels=pixels.reshape((-1,4));w,h=image.size
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.transform(bm,matrix=o.matrix_world,verts=list(bm.verts))
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    result=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,z),plane_no=(0,0,1),dist=.000001)
    bm.normal_update();pending={e for e in result['geom_cut'] if isinstance(e,bmesh.types.BMEdge)};rings=[]
    while pending:
     edge=pending.pop();verts=set(edge.verts);stack=[edge]
     while stack:
      for v in stack.pop().verts:
       for linked in v.link_edges:
        if linked in pending:pending.remove(linked);verts.update(linked.verts);stack.append(linked)
     if len(verts)>=5:
      center=sum((v.co for v in verts),Vector())/len(verts)
      rings.append(((center.x-cx)**2+(center.y-cy)**2,verts))
    if not rings:bm.free();continue
    distance,selected=min(rings,key=lambda r:r[0])
    if distance>.01:bm.free();continue
    uv_layer=bm.loops.layers.uv.active
    for v in selected:
     p=v.co;normal=v.normal.normalized();loop_colors=[]
     for loop in v.link_loops:
      uv=loop[uv_layer].uv;loop_colors.append(pixels[(int(uv.y*h)%h)*w+(int(uv.x*w)%w),:3])
     color=np.mean(loop_colors,axis=0)
     points.append((math.atan2(-(p.y-cy),p.x-cx)%(2*math.pi),[p.x-cx,-(p.y-cy)],[float(c) for c in color],[normal.x,normal.z,-normal.y]))
    bm.free()
   if len(points)<6:raise RuntimeError('Insufficient interface '+name)
   points.sort(key=lambda p:p[0]);angles=[p[0] for p in points];ring=[];colors=[];normals=[]
   for i in range(N):
    angle=2*math.pi*i/N;j=bisect.bisect_right(angles,angle)%len(points);a=points[(j-1)%len(points)];b=points[j];aa=a[0];bb=b[0]
    if bb<=aa:bb+=2*math.pi
    at=angle if angle>=aa else angle+2*math.pi;f=(at-aa)/max(.000001,bb-aa)
    ring.append([a[1][k]*(1-f)+b[1][k]*f for k in range(2)]);colors.append([a[2][k]*(1-f)+b[2][k]*f for k in range(3)])
    normals.append([a[3][k]*(1-f)+b[3][k]*f for k in range(3)])
   levels.append({'ring':ring,'colors':colors,'normals':normals})
  samples.append({'sides':N,'levels':levels})
 out=ROOT/'assets/tripo/animated'/f'{name}-interfaces.json';out.write_text(json.dumps(samples,separators=(',',':')))
 profile['interfaces']='res://'+str(out.relative_to(ROOT));print('INTERFACE',name,flush=True)
path.write_text(json.dumps(profiles,indent=2))
