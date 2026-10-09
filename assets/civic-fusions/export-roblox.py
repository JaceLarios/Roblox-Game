"""Export approved scenes without editing them. Blender 5.2, indices [start,end)."""
import bpy,bmesh,json,math,hashlib,sys,re
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent;OUT=P/'roblox';OUT.mkdir(exist_ok=True)
(OUT/'meshes').mkdir(exist_ok=True);(OUT/'textures').mkdir(exist_ok=True)
SCALE=5.2/3.934462308883667
catalog=json.loads((P/'v2/catalog.json').read_text())
ghosts=['Wisp','Skullsmoke','Oracle','Graveyard','Ecto','Banshee','Poltergeist','Coffin','Cauldron','Specter','Wraith','Soul','Hearse','Reaper','Haunted']
entries=[{'name':'Civic','blend':str(P/'source/Honda-Civic-Loose-Bumper-v4.blend'),'addon':None}]+[{'name':r['model'] if i<16 else ghosts[i-16]+' Civic','blend':str(P/'v2'/r['blend']),'addon':r['addon'],'event':ghosts[i-16] if i>=16 else None}for i,r in enumerate(catalog)]
def slug(s):return re.sub(r'[^A-Za-z0-9]+','_',s).strip('_')
def principal(m):return next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) if m and m.use_nodes else None
def xyz(v):return [round(v[0]*SCALE,6),round(v[2]*SCALE,6),round(-v[1]*SCALE,6)]
def normal(v):return [round(v[0],6),round(v[2],6),round(-v[1],6)]
def image_file(image):
 name=re.sub(r'\.\d{3}$','',image.name);name=slug(Path(name).stem)+'.png';target=OUT/'textures'/name
 if not target.exists():
  copy=image.copy();copy.filepath_raw=str(target);copy.file_format='PNG'
  if max(copy.size)>2048:copy.scale(round(copy.size[0]*2048/max(copy.size)),round(copy.size[1]*2048/max(copy.size)))
  copy.save();bpy.data.images.remove(copy)
 return 'textures/'+name
def const(value):
 value=max(0,min(1,value));name=f'constant-{round(value*255):03d}.png';target=OUT/'textures'/name
 if not target.exists():
  im=bpy.data.images.new(name,4,4,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels=[value,value,value,1]*16;im.filepath_raw=str(target);im.file_format='PNG';im.save();bpy.data.images.remove(im)
 return 'textures/'+name
def rusty_bakes(source,material):
 prefix=slug(source.name+'_'+material.name);result={key:'textures/'+prefix+'-'+key+'.png' for key in ['ColorMap','NormalMap','RoughnessMap']}
 if all((OUT/v).exists()for v in result.values()):return result
 mesh=source.data.copy();bm=bmesh.new();bm.from_mesh(mesh)
 bad=[f for f in bm.faces if mesh.materials[f.material_index]!=material];bmesh.ops.delete(bm,geom=bad,context='FACES');bm.to_mesh(mesh);bm.free()
 mesh.materials.clear();mesh.materials.append(material)
 for f in mesh.polygons:f.material_index=0
 ob=bpy.data.objects.new('Rust surface bake',mesh);bpy.context.collection.objects.link(ob);ob.matrix_world=source.matrix_world
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=1;s.render.bake.margin=12;s.render.bake.use_selected_to_active=False;s.render.bake.use_clear=True
 nt=material.node_tree;bs=principal(material);output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');original=output.inputs['Surface'].links[0].from_socket
 for key,kind in [('ColorMap','EMIT'),('NormalMap','NORMAL'),('RoughnessMap','ROUGHNESS')]:
  im=bpy.data.images.new(prefix+key,2048,2048,alpha=False)
  if key!='ColorMap':im.colorspace_settings.name='Non-Color'
  node=nt.nodes.new('ShaderNodeTexImage');node.image=im;nt.nodes.active=node;emit=None
  if key=='ColorMap':
   emit=nt.nodes.new('ShaderNodeEmission');pin=bs.inputs['Base Color']
   if pin.is_linked:nt.links.new(pin.links[0].from_socket,emit.inputs['Color'])
   else:emit.inputs['Color'].default_value=pin.default_value
   nt.links.new(emit.outputs[0],output.inputs['Surface'])
  bpy.ops.object.bake(type=kind)
  im.filepath_raw=str(OUT/result[key]);im.file_format='PNG';im.save();nt.nodes.remove(node);bpy.data.images.remove(im)
  if emit:nt.links.new(original,output.inputs['Surface']);nt.nodes.remove(emit)
 bpy.data.objects.remove(ob,do_unlink=True);bpy.data.meshes.remove(mesh)
 return result
def appearance(mat,ob,isbase):
 bs=principal(mat);name=mat.name if mat else 'Default';lo=name.lower()
 co=list(bs.inputs['Base Color'].default_value[:3])if bs else [.2]*3
 r={'color':co,'transparency':0,'finish':'SmoothPlastic','maps':{}}
 if not bs:return r
 metal=bs.inputs['Metallic'].default_value;rough=bs.inputs['Roughness'].default_value
 transmission=bs.inputs['Transmission Weight'].default_value;alpha=bs.inputs['Alpha'].default_value
 if transmission>.3:
  r.update(finish='Glass',transparency=.7 if 'headlamp' in lo else .38 if name=='Glass_MAT' else .24);return r
 if bs.inputs['Emission Strength'].default_value>0 and max(bs.inputs['Emission Color'].default_value[:3])>.03 and ('energy'in lo or bs.inputs['Emission Strength'].default_value>1):
  r.update(finish='Neon',color=list(bs.inputs['Emission Color'].default_value[:3]),transparency=1-alpha);return r
 r['transparency']=1-alpha
 if isbase and name in ['Body_MAT','Scuffed painted plastic bumpers']:
  r['maps']=rusty_bakes(ob,mat);r['maps']['MetalnessMap']=const(metal);r['color']=[1,1,1];return r
 if name=='Body_MAT':
  r['maps']['ColorMap']=image_file(next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'and n.image))
  mix=bs.inputs['Base Color'].links[0].from_node
  if mix.type=='MIX_RGB':r['color']=list(mix.inputs[2].default_value[:3])
 elif name=='Tire_MAT':
  for n in mat.node_tree.nodes:
   if n.type=='TEX_IMAGE'and n.image:
    key='NormalMap' if 'Normal' in n.image.name else 'RoughnessMap' if 'Roughness' in n.image.name else 'ColorMap';r['maps'][key]=image_file(n.image)
  r['color']=[.18]*3
 elif 'carbon' in lo:
  r['variant']='AddonCarbonTwill';r['color']=[.17,.18,.2];return r
 else:
  images=[n.image.name for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'and n.image]
  kind=next((k for k in ['Cast','Brushed','Enamel','Rubber','Oxidized']if any(i.startswith(k+'_')for i in images)),None)
  if kind:r['variant']='AddonDetail_'+kind+'_v2';return r
  if isbase and name=='Silver_MAT':r['variant']='AddonDetail_Brushed_v2';r['color']=[.23,.25,.25];return r
 r['maps'].setdefault('RoughnessMap',const(rough));r['maps']['MetalnessMap']=const(metal)
 return r
def export(entry):
 bpy.ops.wm.open_mainfile(filepath=entry['blend']);bpy.context.view_layer.update();isbase=entry['name']=='Civic'
 original=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}and not o.hide_render and o.name!='PREVIEW FLOOR']
 wheelinfo={}
 for ob in original:
  if re.fullmatch(r'Wheel_[FR][LR]',ob.name):
   pts=[ob.matrix_world@Vector(v)for v in ob.bound_box];lo=Vector([min(v[i]for v in pts)for i in range(3)]);hi=Vector([max(v[i]for v in pts)for i in range(3)])
   wheelinfo[ob.name]={'id':ob.name,'pivot':xyz((lo+hi)/2),'radius':round((hi.z-lo.z)/2*SCALE,6)}
 # Budget dense car shell and rolling meshes separately, retaining much more of the small addons.
 counts={};deps=bpy.context.evaluated_depsgraph_get()
 for ob in original:
  ev=ob.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles();counts[ob.name]=len(me.loop_triangles);ev.to_mesh_clear()
 addon_total=sum(n for name,n in counts.items()if name!='Honda_Civic_Body'and not re.fullmatch(r'Wheel_[FR][LR]',name))
 groups={};looks={};total_source=sum(counts.values())
 for ob in original:
  wheel=ob.get('WheelGroup')or(ob.name[:8]if ob.name.startswith('Wheel_')else '')
  if wheel not in wheelinfo:wheel=''
  if ob.name=='Honda_Civic_Body':target=39000
  elif re.fullmatch(r'Wheel_[FR][LR]',ob.name):target=3400
  else:target=max(100,int(counts[ob.name]*min(1,24000/max(addon_total,1))))
  source_mats={m.name:appearance(m,ob,isbase)for m in ob.data.materials if m}
  deps=bpy.context.evaluated_depsgraph_get();ev=ob.evaluated_get(deps);mesh=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=deps)
  temp=bpy.data.objects.new('Civic export temporary',mesh);bpy.context.collection.objects.link(temp);temp.matrix_world=ob.matrix_world
  if counts[ob.name]>target:
   d=temp.modifiers.new('Runtime geometry budget','DECIMATE');d.ratio=target/counts[ob.name];d.use_collapse_triangulate=True
  deps=bpy.context.evaluated_depsgraph_get();ev=temp.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles();nm=ob.matrix_world.to_3x3().inverted().transposed()
  for t in me.loop_triangles:
   mat=me.materials[t.material_index];look=source_mats[mat.name];key=(mat.name,wheel,json.dumps(look,sort_keys=True))
   g=groups.setdefault(key,{'material':mat.name,'appearance':look,'wheel':wheelinfo.get(wheel),'v':[],'n':[],'uv':[],'tri':[],'components':set()});g['components'].add(ob.name);face=[]
   for li in t.loops:
    loop=me.loops[li];co=ob.matrix_world@me.vertices[loop.vertex_index].co;n=(nm@me.corner_normals[li].vector).normalized();uv=list(me.uv_layers.active.data[li].uv)if me.uv_layers.active else [0,0]
    face.append(len(g['v']));g['v'].append(xyz(co));g['n'].append(normal(n));g['uv'].append([round(uv[0],6),round(1-uv[1],6)])
   g['tri'].append(face)
  ev.to_mesh_clear();bpy.data.objects.remove(temp,do_unlink=True);bpy.data.meshes.remove(mesh)
 parts=[];points=[]
 for g in groups.values():
  for offset in range(0,len(g['tri']),6500):
   vv=g['v'][offset*3:(offset+6500)*3];nn=g['n'][offset*3:(offset+6500)*3];uv=g['uv'][offset*3:(offset+6500)*3]
   lo=[min(v[i]for v in vv)for i in range(3)];hi=[max(v[i]for v in vv)for i in range(3)];center=[(lo[i]+hi[i])/2 for i in range(3)];points.extend([lo,hi])
   data={'vertices':[[round(v[i]-center[i],6)for i in range(3)]for v in vv],'normals':nn,'uvs':uv,'triangles':[[j*3,j*3+1,j*3+2]for j in range(len(vv)//3)]}
   encoded=json.dumps(data,separators=(',',':'));digest=hashlib.sha256(encoded.encode()).hexdigest();file='meshes/'+digest+'.json'
   if not (OUT/file).exists():(OUT/file).write_text(encoded)
   parts.append({'name':('Glass_' if g['appearance']['finish']=='Glass' else '')+g['material']+'_'+str(len(parts)), 'center':center,'size':[hi[i]-lo[i]for i in range(3)],'appearance':g['appearance'],'wheel':g['wheel'],'triangles':len(data['triangles']),'geometryHash':digest,'file':file,'components':sorted(g['components'])})
 target=[max(v[i]for v in points)-min(v[i]for v in points)for i in range(3)]
 result={'name':entry['name'],'addon':entry['addon'],'event':entry.get('event'),'parts':parts,'triangles':sum(p['triangles']for p in parts),'sourceTriangles':total_source,'targetSize':target,'expectedWheels':len(wheelinfo),'noseAxis':'+Z','source':Path(entry['blend']).name}
 assert result['triangles']<90000,result['triangles']
 (OUT/(slug(entry['name'])+'.json')).write_text(json.dumps(result,indent=2))
 print('EXPORTED',entry['name'],len(parts),result['triangles'],len(wheelinfo),flush=True)
args=sys.argv[sys.argv.index('--')+1:]if '--'in sys.argv else []
start=int(args[0])if args else 0;end=int(args[1])if len(args)>1 else len(entries)
for entry in entries[start:end]:export(entry)
(OUT/'manifest.json').write_text(json.dumps([{'name':e['name'],'addon':e['addon'],'event':e.get('event'),'file':slug(e['name'])+'.json'}for e in entries],indent=2))
