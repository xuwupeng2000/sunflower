"""Blender: preserve the supplied planter skins, normalize, and join a recessed soil disk."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
POTS=[('rabbit-pot','77d7cd03-86d8-486e-ada0-5399cc7b6c5c',.74,.34),('hedgehog-pot','abd21086-1fdf-4399-93eb-c496505f8dfd',.80,.29)]
for name,ident,soil_y,radius in POTS:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 source=ROOT/'assets/staging/tripo'/('tripo_convert_'+ident)/('tripo_convert_'+ident+'.fbx')
 bpy.ops.import_scene.fbx(filepath=str(source))
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
 points=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box]
 lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
 centre=Vector(((hi.x+lo.x)*.5,(hi.y+lo.y)*.5,lo.z));scale=1/(hi.z-lo.z)
 for o in objects:
  matrix=o.matrix_world.copy()
  for vertex in o.data.vertices:vertex.co=(matrix@vertex.co-centre)*scale
  o.matrix_world.identity()
  if len(o.data.polygons)>40000:
   bpy.context.view_layer.objects.active=o
   modifier=o.modifiers.new('Mobile mesh','DECIMATE');modifier.ratio=40000/len(o.data.polygons)
   bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=.025,location=(0,0,soil_y-.0125))
 soil=bpy.context.object;soil.name='RecessedSoil'
 material=bpy.data.materials.new('PottingSoil');material.use_nodes=True
 bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(.105,.056,.021,1);bsdf.inputs['Roughness'].default_value=1
 soil.data.materials.append(material)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects+[soil]:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
 joined=bpy.context.object;joined.name=name
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/tripo'/(name+'.glb')),export_format='GLB',use_selection=True)
 print('IMPORTED',name,'soil',soil_y,'faces',len(joined.data.polygons),flush=True)
