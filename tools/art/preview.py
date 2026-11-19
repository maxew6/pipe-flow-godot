import sys
from PIL import Image
import scene_a as A
from common import *
layers = []
sky = A.build_sky(); layers.append(sky)
for i,(x,y,w,h,s) in enumerate([(40,380,470,230,1),(640,300,400,200,2),(120,820,520,250,3),(760,1080,360,180,4)]):
    c = Image.new('RGBA',(A.W,A.H),(0,0,0,0)); blit(c, A.cloud(w,h,s), x, y); layers.append(c)
layers.append(A.build_mountains()); layers.append(A.build_midground())
out = layers[0].copy()
for l in layers[1:]: out.alpha_composite(l)
out.convert('RGB').resize((600,1200)).save('/home/claude/preview_a.png')
print('ok')
