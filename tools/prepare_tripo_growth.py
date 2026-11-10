"""Run with Blender --background --python tools/prepare_tripo_growth.py.
Split approved plants across a narrow bare-stem section; retain original geometry above/below.
"""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
profiles_path=ROOT/"assets/tripo/animated/profiles.json"
profiles=json.loads(profiles_path.read_text()) if profiles_path.exists() else {}
for name,height,low,high in [('sunflower-new',1.6,.58,.98),('phalaenopsis-new',1.3,.43,.72),('clivia',1.3,.5,.86)]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/tripo'/f'{name}.glb'))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in meshes:
  bpy.context.view_layer.objects.active=o
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 originals=[o.data.copy() for o in meshes]
 # Cut only the central stalk area, not any leaf blades crossing the same height.
 cut={'sunflower-new':.20,'phalaenopsis-new':.40,'clivia':.78}[name]
 bases=[];tops=[];ring_points=[]
 for source in meshes:
  bm=bmesh.new();bm.from_mesh(source.data)
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
  faces=[f for f in bm.faces if min(v.co.z for v in f.verts)<=cut<=max(v.co.z for v in f.verts) and all((min((v.co.x-.01020)**2+(v.co.y-.03839)**2,(v.co.x+.11469)**2+(v.co.y-.01010)**2)<.045**2) if name=='phalaenopsis-new' else (abs(v.co.x)<.12 and abs(v.co.y)<.12) for v in f.verts)]
  edges=set(e for f in faces for e in f.edges);verts=set(v for f in faces for v in f.verts)
  result=bmesh.ops.bisect_plane(bm,geom=list(verts)+list(edges)+faces,dist=.000001,plane_co=(0,0,cut),plane_no=(0,0,1))
  cut_edges=[g for g in result['geom_cut'] if isinstance(g,bmesh.types.BMEdge)]
  pending=set(cut_edges)
  while pending:
   seed=pending.pop();rv=set(seed.verts);stack=[seed]
   while stack:
    edge=stack.pop()
    for v in edge.verts:
     for linked in v.link_edges:
      if linked in pending:pending.remove(linked);rv.update(linked.verts);stack.append(linked)
   if len(rv)>=3:ring_points.append([v.co.copy() for v in rv])
  bmesh.ops.split_edges(bm,edges=cut_edges)
  pending=set(bm.verts);top_vertices=set();base_vertices=set()
  while pending:
   seed=pending.pop();component={seed};stack=[seed]
   while stack:
    v=stack.pop()
    for e in v.link_edges:
     other=e.other_vert(v)
     if other in pending:pending.remove(other);component.add(other);stack.append(other)
   loz=min(v.co.z for v in component);hiz=max(v.co.z for v in component)
   if loz<.04 and hiz>height*.9:raise RuntimeError('Stem not separated: '+name)
   # Connected parts keep their ENTIRE leaves, even when a leaf dips below the cut plane.
   is_top=loz>cut-.001 or (hiz>height*.84 and loz>.04)
   (top_vertices if is_top else base_vertices).update(component)
  bm.verts.index_update();bm.faces.index_update()
  for side,keep in [('Base',base_vertices),('Top',top_vertices)]:
   keep_indices={v.index for v in keep};copy=bm.copy();copy.verts.ensure_lookup_table()
   bmesh.ops.delete(copy,geom=[v for v in copy.verts if v.index not in keep_indices],context='VERTS')
   if not copy.faces:copy.free();continue
   # Interface is joined to the generated bridge: no internal cap that can flash as a bright seam.
   mesh=bpy.data.meshes.new(name+'_'+side);copy.to_mesh(mesh);copy.free()
   for mat in source.data.materials:mesh.materials.append(mat)
   obj=bpy.data.objects.new(side+'_'+source.name,mesh);bpy.context.collection.objects.link(obj)
   (bases if side=='Base' else tops).append(obj)
  bm.free();bpy.data.objects.remove(source,do_unlink=True)
 centers=[]
 for ring in ring_points:
  c=sum(ring,Vector())/len(ring);r=sum((p-c).length for p in ring)/len(ring)
  centers.append({'x':c.x,'z':-c.y,'radius':max(.006,r)})
 if not centers:raise RuntimeError('No stalk cut for '+name)
 pivot=Vector((sum(c['x'] for c in centers)/len(centers),-sum(c['z'] for c in centers)/len(centers),cut))
 crown=bpy.data.objects.new('Crown',None);bpy.context.collection.objects.link(crown);crown.location=pivot
 for o in tops:
  for v in o.data.vertices:v.co-=pivot
  o.parent=crown
 # Reuse textured sidewalls from the original stalk instead of procedural cylinders.
 sample_length=.12
 for stem_index,spec in enumerate(centers):
  center=Vector((spec['x'],-spec['z'],cut))
  radius=spec['radius']
  low_z=cut-sample_length*.5;high_z=cut+sample_length*.5
  for original in originals:
   segment=bmesh.new();segment.from_mesh(original)
   # Follow the source stalk's centreline at each end, allowing its original lean.
   anchors=[]
   for z in [low_z,high_z]:
    pts=[]
    for edge in original.edges:
     va,vb=(original.vertices[i].co for i in edge.vertices)
     if (va.z-z)*(vb.z-z)<0:
      point=va.lerp(vb,(z-va.z)/(vb.z-va.z))
      if (Vector((point.x,point.y,cut))-center).length<max(.05,radius*2.4):pts.append(point)
    anchors.append(sum(pts,Vector())/len(pts) if pts else Vector((center.x,center.y,z)))
   bmesh.ops.bisect_plane(segment,geom=list(segment.verts)+list(segment.edges)+list(segment.faces),plane_co=(0,0,low_z),plane_no=(0,0,1),clear_inner=True,dist=.000001)
   bmesh.ops.bisect_plane(segment,geom=list(segment.verts)+list(segment.edges)+list(segment.faces),plane_co=(0,0,high_z),plane_no=(0,0,1),clear_outer=True,dist=.000001)
   unwanted=[]
   for face in segment.faces:
    if any((Vector((v.co.x,v.co.y,0))-Vector((anchors[0].lerp(anchors[1],(v.co.z-low_z)/sample_length).x,anchors[0].lerp(anchors[1],(v.co.z-low_z)/sample_length).y,0))).length>max(.03,radius*1.7) for v in face.verts):unwanted.append(face)
   bmesh.ops.delete(segment,geom=unwanted,context='FACES')
   loose=[v for v in segment.verts if not v.link_faces]
   if loose:bmesh.ops.delete(segment,geom=loose,context='VERTS')
   if len(segment.faces)<4:segment.free();continue
   # Straighten only the sampled stalk's centreline; preserve its irregular surface and UVs.
   for v in segment.verts:
    t=(v.co.z-low_z)/sample_length
    c=anchors[0].lerp(anchors[1],t)
    v.co=Vector((v.co.x-c.x,v.co.y-c.y,v.co.z-low_z))
   mesh=bpy.data.meshes.new('StemSample_%d'%stem_index);segment.to_mesh(mesh);segment.free()
   for material in original.materials:mesh.materials.append(material)
   sample=bpy.data.objects.new('StemSample_%d'%stem_index,mesh);bpy.context.collection.objects.link(sample)
   # Template lives in its own export, never as visible geometry in the whole plant.
   bpy.ops.object.select_all(action='DESELECT');sample.select_set(True)
   path='assets/tripo/animated/%s-stem-%d.glb'%(name,stem_index)
   bpy.ops.export_scene.gltf(filepath=str(ROOT/path),export_format='GLB',use_selection=True)
   spec['sample']='res://'+path
   bpy.data.objects.remove(sample,do_unlink=True)
   break
  if 'sample' not in spec:raise RuntimeError('Could not sample stalk: '+name)
 old=profiles.get(name,{})
 for i,center in enumerate(centers):
  if i<len(old.get('stems',[])) and 'skin' in old['stems'][i]:center['skin']=old['stems'][i]['skin']
 profiles[name]={**old,'height':height,'cut_height':cut,'pivot':[pivot.x,pivot.z,-pivot.y],'stems':centers,'section_height':sample_length}
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/tripo/animated'/f'{name}.glb'),export_format='GLB')
 print('SPLIT',name,profiles[name],flush=True)
(ROOT/'assets/tripo/animated/profiles.json').write_text(json.dumps(profiles,indent=2))
