from pathlib import Path
import json
import numpy as np
from PIL import Image
out=Path(__file__).parent/'textures';out.mkdir(exist_ok=True)
N=256;rng=np.random.default_rng(924)
def blur(a,n=1):
 for _ in range(n):a=(a+np.roll(a,1,0)+np.roll(a,-1,0)+np.roll(a,1,1)+np.roll(a,-1,1))/5
 return a
manifest=[]
for kind in ['Cast','Brushed','Enamel','Rubber','Oxidized']:
 noise=rng.random((N,N));fine=rng.random((N,N));coarse=blur(noise,12);coarse=(coarse-coarse.min())/(coarse.max()-coarse.min())
 scratches=np.ones((N,N))
 for j in range(40 if kind=='Brushed' else 13):
  x,y=rng.integers(0,N,2);length=int(rng.integers(9,70))
  for k in range(length):scratches[(y+k//12)%N,(x+k)%N]=.15
 if kind=='Cast':
  h=blur(noise)*.8+fine*.2;albedo=.67+coarse*.20+fine*.08;rough=.66+fine*.23;metal=.78;strength=1.2
 elif kind=='Brushed':
  grain=np.repeat(rng.random((N,1)),N,axis=1);h=grain*.55+fine*.04+(1-scratches)*-.08
  albedo=.78+grain*.16;rough=.23+grain*.22+(1-scratches)*.22;metal=.98;strength=.65
 elif kind=='Enamel':
  chips=(blur(noise)>.70).astype(float);h=blur(fine)*.1-chips*.13-(1-scratches)*.05
  albedo=.90+coarse*.09-chips*.26-(1-scratches)*.18;rough=.29+coarse*.16+chips*.28;metal=.12;strength=.60
 elif kind=='Rubber':
  h=blur(noise)*.35+fine*.2;albedo=.66+coarse*.20;rough=.77+fine*.18;metal=0;strength=.7
 else:
  h=coarse*.45+fine*.35;albedo=.45+coarse*.38+fine*.10;rough=.72+fine*.25;metal=.27;strength=1.5
 dx=(np.roll(h,-1,1)-np.roll(h,1,1))*strength;dy=(np.roll(h,-1,0)-np.roll(h,1,0))*strength
 normal=np.stack([-dx,-dy,np.ones_like(dx)],axis=2);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
 maps={}
 for key,a in [('ColorMap',albedo),('NormalMap',normal*.5+.5),('RoughnessMap',rough),('MetalnessMap',np.full((N,N),metal))]:
  if a.ndim==2:a=np.repeat(a[:,:,None],3,axis=2)
  rgb=np.uint8(np.clip(a,0,1)*255);rgba=np.dstack((rgb,np.full((N,N),255,dtype=np.uint8)))
  Image.fromarray(rgba).save(out/f'{kind}_{key}.png');maps[key]=rgba.flatten().tolist()
 (out/f'{kind}.json').write_text(json.dumps({'name':kind,'size':N,'maps':maps},separators=(',',':')))
 manifest.append({'name':kind,'file':f'textures/{kind}.json'})
(out/'manifest.json').write_text(json.dumps(manifest))
print('Created five seamless material sets with color, normal, roughness and metalness maps.')
