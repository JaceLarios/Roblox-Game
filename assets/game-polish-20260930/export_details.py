import bpy,os,json
root=os.path.abspath('outputs/game-polish-20260930/detail-maps');os.makedirs(root,exist_ok=True);out=[]
for name in ['CT_CorsaTex_NeroAde_001.001','CT_Floor_NeroAde_001.001','CT_Floormat_NeroAde.001','CT_Leather_TerraKapnos.001','CT_Leather_TerraKapnosForato.001','E_Plastic_Satin_Smooth_001.001','gridFront.001','gridHoney.001','gridLaterals.001','gridTop.001','Light_001_001.001']:
 m=bpy.data.materials.get(name)
 if not m:continue
 n=next((n for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image),None)
 if n:
  fn='detail-'+str(len(out))+'.png';n.image.save_render(os.path.join(root,fn));out.append({'material':name,'file':fn,'alpha':name.startswith('grid')})
open(os.path.join(root,'manifest.json'),'w').write(json.dumps(out))
