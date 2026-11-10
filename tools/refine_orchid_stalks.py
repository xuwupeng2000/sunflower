"""Narrow the local Phalaenopsis insertion collars; preserve UVs and all flower/leaf geometry."""
import bpy,shutil,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'assets/tripo/phalaenopsis-new.glb';backup=ROOT/'assets/staging/phalaenopsis-before-stalk-refinement.glb'
backup.parent.mkdir(exist_ok=True)
if not backup.exists():shutil.copy2(source,backup)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(backup))
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 for v in o.data.vertices:
  z=v.co.z
  if abs(z-.4)>=.04:continue
  # Follow the two original stalk centrelines in the short collar region only.
  candidates=[(-.11469+(z-.4)*.05,.01010+(z-.4)*.50),(.01020+(z-.4)*.56,.03839+(z-.4)*.61)]
  cx,cy=min(candidates,key=lambda p:(v.co.x-p[0])**2+(v.co.y-p[1])**2)
  r=math.hypot(v.co.x-cx,v.co.y-cy)
  if r>.036:continue
  t=abs(z-.4)/.04;weight=1-t*t*(3-2*t);factor=1-.36*weight
  v.co.x=cx+(v.co.x-cx)*factor;v.co.y=cy+(v.co.y-cy)*factor
bpy.ops.export_scene.gltf(filepath=str(source),export_format='GLB')
