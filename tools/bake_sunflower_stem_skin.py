"""Reproject original sunflower stalk albedo to a cylindrical UV strip for new growth."""
import bpy,math,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/tripo/animated/sunflower-new-stem-0.glb'))
source=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=source;source.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for material in source.data.materials:
 bs=material.node_tree.nodes.get('Principled BSDF')
 if bs and bs.inputs['Base Color'].links:
  material.node_tree.links.new(bs.inputs['Base Color'].links[0].from_socket,bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=1
texture=bpy.data.images.new('SunflowerOriginalStalkSkin',width=512,height=512,alpha=False)
target=source.copy();target.data=source.data.copy();bpy.context.collection.objects.link(target)
target.data.materials.clear();material=bpy.data.materials.new('BakeTarget');material.use_nodes=True
node=material.node_tree.nodes.new('ShaderNodeTexImage');node.image=texture;material.node_tree.nodes.active=node;target.data.materials.append(material)
uv=target.data.uv_layers.new(name='Cylindrical')
lo=min(v.co.z for v in target.data.vertices);hi=max(v.co.z for v in target.data.vertices)
for face in target.data.polygons:
 values=[]
 for li in face.loop_indices:
  p=target.data.vertices[target.data.loops[li].vertex_index].co;u=(math.atan2(-p.y,p.x)%(2*math.pi))/(2*math.pi);values.append((li,u,(p.z-lo)/(hi-lo)))
 seam=max(v[1] for v in values)-min(v[1] for v in values)>.5
 for li,u,v in values:uv.data[li].uv=(u+1 if seam and u<.5 else u,v)
target.data.uv_layers.active=uv;uv.active_render=True
bpy.ops.object.select_all(action='DESELECT');source.select_set(True);target.select_set(True);bpy.context.view_layer.objects.active=target
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.bake.use_selected_to_active=True;scene.render.bake.max_ray_distance=.01;scene.render.bake.cage_extrusion=.002;scene.render.bake.margin=8
bpy.ops.object.bake(type='EMIT')
texture.filepath_raw=str(ROOT/'assets/tripo/animated/sunflower-stem-skin.png');texture.file_format='PNG';texture.save()
p=ROOT/'assets/tripo/animated/profiles.json';profiles=json.loads(p.read_text());profiles['sunflower-new']['stems'][0]['skin']='res://assets/tripo/animated/sunflower-stem-skin.png';p.write_text(json.dumps(profiles,indent=2))
