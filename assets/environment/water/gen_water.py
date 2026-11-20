# Genera mappe d'acqua tileabili (CC0: create proceduralmente, nessuna fonte esterna).
import math, random, sys
from PIL import Image
N = 512
random.seed(7)
waves = []
for i in range(28):
    # vettore d'onda intero => tileable; direzioni concentrate (vento) con dispersione
    mag = random.choice([2,3,3,4,5,6,7,9,11,14,18,23])
    ang = random.gauss(0.5, 0.9)
    kx = max(-40, min(40, round(mag*math.cos(ang)))); ky = max(-40, min(40, round(mag*math.sin(ang))))
    if kx == 0 and ky == 0: kx = 3
    k = math.hypot(kx, ky)
    amp = 1.0 / (k ** 1.15)
    waves.append((kx, ky, amp, random.uniform(0, 6.283)))
tw = 2*math.pi/N
nrm = Image.new("RGB", (N, N)); hgt = Image.new("L", (N, N))
npx = nrm.load(); hpx = hgt.load()
# normalizzazione pendenza
sl = 0.0; samples=[]
data = [[None]*N for _ in range(N)]
for y in range(N):
    for x in range(N):
        h = dx = dy = 0.0
        for kx, ky, a, ph in waves:
            arg = (kx*x + ky*y)*tw + ph
            # onde "appuntite" (creste strette): h = 1-|sin| mescolato
            s = math.sin(arg); c = math.cos(arg)
            h += a * s; dx += a * kx * tw * c; dy += a * ky * tw * c
        data[y][x] = (h, dx, dy)
        sl = max(sl, abs(dx), abs(dy))
hs = [d[0] for r in data for d in r]; hmin, hmax = min(hs), max(hs)
strength = 0.55 / (sl*0.55)
for y in range(N):
    for x in range(N):
        h, dx, dy = data[y][x]
        nx, ny, nz = -dx*strength*2.0, -dy*strength*2.0, 1.0
        l = math.sqrt(nx*nx+ny*ny+nz*nz); nx/=l; ny/=l; nz/=l
        npx[x, y] = (int((nx*.5+.5)*255), int((ny*.5+.5)*255), int((nz*.5+.5)*255))
        hpx[x, y] = int((h-hmin)/(hmax-hmin)*255)
out = sys.argv[1]
nrm.save(out + "/sea_normal.png"); hgt.save(out + "/sea_height.png")
