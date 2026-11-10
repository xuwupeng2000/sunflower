"""Blender: normalize the approved Tripo clivia stem kit, preserving original UV/materials."""
import bpy,bmesh,json,math,sys,argparse
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--asset',default='clivia')
parser.add_argument('--source-blend',default='build/blender_previews/stem-kit-aacb.blend')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
SOURCE=ROOT/args.source_blend
if SOURCE.exists():
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
else:
 # Regenerate from the preserved raw package when the local preview .blend is absent.
 ident={'clivia':'aacb9f28-c8b1-438c-b360-09d415cad57c','sunflower-new':'f2cbe82c-c0d7-49c3-a23f-15b5e23f00a0'}[args.asset]
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.fbx(filepath=str(ROOT/'assets/staging/tripo'/('tripo_convert_'+ident)/('tripo_convert_'+ident+'.fbx')))
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  bpy.context.view_layer.objects.active=obj;bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(obj.data);bm.free()
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
profiles=json.loads((ROOT/'assets/tripo/animated/profiles.json').read_text());profile=profiles[args.asset];radius=profile['stems'][0]['radius'];length=profile['section_height']
objects=sorted([o for o in bpy.context.scene.objects if o.type=='MESH'],key=lambda o:sum(v.co.x for v in o.data.vertices)/len(o.data.vertices))
out=ROOT/'assets/tripo/animated'/(args.asset+'-kit');out.mkdir(exist_ok=True)
paths=[]
for i,o in enumerate(objects):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 if len(o.data.polygons)>14000:
  mod=o.modifiers.new('Mobile mesh','DECIMATE');mod.ratio=14000/len(o.data.polygons);bpy.ops.object.modifier_apply(modifier=mod.name)
 lo=min(v.co.z for v in o.data.vertices);hi=max(v.co.z for v in o.data.vertices);span=hi-lo
 bm=bmesh.new();bm.from_mesh(o.data)
 for z,inner,outer in [(lo+span*.035,True,False),(hi-span*.035,False,True)]:
  res=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,z),plane_no=(0,0,1),clear_inner=inner,clear_outer=outer,dist=.000001)
  edges=[e for e in res['geom_cut'] if isinstance(e,bmesh.types.BMEdge)]
  if edges:
   try:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
   except:pass
 bm.to_mesh(o.data);bm.free()
 lo=min(v.co.z for v in o.data.vertices);hi=max(v.co.z for v in o.data.vertices)
 cx=(min(v.co.x for v in o.data.vertices)+max(v.co.x for v in o.data.vertices))*.5;cy=(min(v.co.y for v in o.data.vertices)+max(v.co.y for v in o.data.vertices))*.5
 # All endpoints share one centred circular interface. Interior retains generated variation.
 sample_r=sum(math.hypot(v.co.x-cx,v.co.y-cy) for v in o.data.vertices if v.co.z<lo+(hi-lo)*.07 or v.co.z>hi-(hi-lo)*.07)
 sample_n=sum(1 for v in o.data.vertices if v.co.z<lo+(hi-lo)*.07 or v.co.z>hi-(hi-lo)*.07)
 source_r=sample_r/max(1,sample_n)
 for v in o.data.vertices:
  t=(v.co.z-lo)/(hi-lo);x=(v.co.x-cx)*radius/source_r;y=(v.co.y-cy)*radius/source_r
  r=math.hypot(x,y)
  blend=max(0,1-min(t,1-t)/.12)
  # Only sidewall vertices at interface need radial normalization; preserve cap interiors.
  if r>radius*.6:
   target=r*(1-blend)+radius*blend
   x*=target/r;y*=target/r
  v.co=(x,y,t*length)
 o.location=(0,0,0);o.name=args.asset+'_Stem_'+chr(65+i)
 path=out/('stem-'+chr(97+i)+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True)
 paths.append('res://'+str(path.relative_to(ROOT)))
 print('KIT',path,tuple(o.dimensions),flush=True)
for spec in profile['stems']:spec['variants']=paths
(ROOT/'assets/tripo/animated/profiles.json').write_text(json.dumps(profiles,indent=2))
