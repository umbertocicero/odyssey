"""Affianca piu' PNG (con trasparenza) su sfondo pergamena. Uso: python3 sheet.py out.png in1.png in2.png ..."""
import sys; from PIL import Image
out=sys.argv[1]; fs=sys.argv[2:]; ims=[Image.open(f).convert('RGBA') for f in fs]
W=sum(i.width for i in ims); c=Image.new('RGBA',(W,max(i.height for i in ims)),(236,224,200,255))
x=0
for i in ims: c.alpha_composite(i,(x,0)); x+=i.width
c.convert('RGB').save(out)
