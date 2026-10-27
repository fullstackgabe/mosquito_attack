"""Rascunho original do chicote (512x512, traço liso) para converter em pixel art."""
import sys, math
from PIL import Image, ImageDraw
OUT=sys.argv[1]; SS=2; W=512*SS
img=Image.new('RGBA',(W,W),(255,255,255,255)); dr=ImageDraw.Draw(img)
def catmull(ps, steps=40):
    out=[]; ps=[ps[0]]+ps+[ps[-1]]
    for i in range(1,len(ps)-2):
        p0,p1,p2,p3=ps[i-1],ps[i],ps[i+1],ps[i+2]
        for s in range(steps):
            t=s/steps
            out.append(tuple(0.5*((2*p1[j])+(-p0[j]+p2[j])*t+(2*p0[j]-5*p1[j]+4*p2[j]-p3[j])*t*t+(-p0[j]+3*p1[j]-3*p2[j]+p3[j])*t**3) for j in range(2)))
    out.append(ps[-2]); return out
def line(pts, r, col):
    for (x,y) in pts:
        dr.ellipse([(x*SS-r*SS),(y*SS-r*SS),(x*SS+r*SS),(y*SS+r*SS)], fill=col)
OUTL=(25,14,6,255); ROPE=(130,78,36,255); HI=(175,115,60,255)
# corda: sai do cabo, sobe, faz um laço grande e sobra uma onda até o alto à direita
rope=catmull([(150,330),(140,230),(200,150),(300,140),(370,200),(360,300),(290,330),(240,280),(270,210),(350,170),(400,190),(430,140),(420,90),(450,60)])
line(rope, 15, OUTL); line(rope, 10, ROPE)
line([(x-3,y-3) for (x,y) in rope], 3, HI)
# ponta desfiada em 3 fios
tip=rope[-1]
for ang in (-0.6,0.0,0.6):
    d=(math.cos(-0.9+ang), math.sin(-0.9+ang))
    seg=[(tip[0]+d[0]*k, tip[1]+d[1]*k) for k in range(0,34,2)]
    line(seg, 8, OUTL)
for ang in (-0.6,0.0,0.6):
    d=(math.cos(-0.9+ang), math.sin(-0.9+ang))
    seg=[(tip[0]+d[0]*k, tip[1]+d[1]*k) for k in range(0,32,2)]
    line(seg, 4, ROPE)
# cabo longo preto com empunhadura em X e aros
h0,h1=(52,500),(150,330)
L=math.dist(h0,h1); d=((h1[0]-h0[0])/L,(h1[1]-h0[1])/L); n=(-d[1],d[0])
def quad(a,b,r):
    return [(a[0]*SS+n[0]*r*SS,a[1]*SS+n[1]*r*SS),(b[0]*SS+n[0]*r*SS,b[1]*SS+n[1]*r*SS),(b[0]*SS-n[0]*r*SS,b[1]*SS-n[1]*r*SS),(a[0]*SS-n[0]*r*SS,a[1]*SS-n[1]*r*SS)]
dr.polygon(quad(h0,h1,30), fill=OUTL); dr.polygon(quad(h0,h1,24), fill=(30,30,30,255))
for k in range(0,int(L)-27,28):   # X da empunhadura
    a=(h0[0]+d[0]*k,h0[1]+d[1]*k); b=(h0[0]+d[0]*(k+28),h0[1]+d[1]*(k+28))
    dr.line([(a[0]*SS+n[0]*22*SS,a[1]*SS+n[1]*22*SS),(b[0]*SS-n[0]*22*SS,b[1]*SS-n[1]*22*SS)], fill=(95,95,95,255), width=6*SS)
    dr.line([(a[0]*SS-n[0]*22*SS,a[1]*SS-n[1]*22*SS),(b[0]*SS+n[0]*22*SS,b[1]*SS+n[1]*22*SS)], fill=(95,95,95,255), width=6*SS)
for c,off in ((h0,0),(h1,0)):
    a=(c[0]-d[0]*8,c[1]-d[1]*8); b=(c[0]+d[0]*8,c[1]+d[1]*8)
    dr.polygon(quad(a,b,36), fill=OUTL); dr.polygon(quad((a[0]+d[0]*3,a[1]+d[1]*3),(b[0]-d[0]*3,b[1]-d[1]*3),31), fill=(55,55,55,255))
img=img.resize((512,512), Image.LANCZOS); img.save(OUT)
