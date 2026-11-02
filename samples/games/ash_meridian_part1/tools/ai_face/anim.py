import sys, math, numpy as np
from PIL import Image, ImageChops
import face as F
def ss(a,b,t):
    t=max(0,min(1,(t-a)/(b-a))); return t*t*(3-2*t)
TS=None
def seq(kind,holo,n=120,W=480,H=360):
    D=F.design(kind); V,T,E=F.build(D); mc=F.mouth_center(D)
    frames=[]
    for i in range(n):
        t=i/(n-1) if TS is None else TS[i]
        fade=ss(0.0,0.15,t)
        o=ss(0.30,0.40,t)
        z=ss(0.40,0.66,t)
        zoom=math.exp(math.log(80.0)*z)
        fx=500+(mc[0]-500)*ss(0.40,0.55,t); fy=490+(mc[1]-490)*ss(0.40,0.55,t)
        tun=ss(0.40,0.97,t)
        img=F.render(D,V,T,E,o,(zoom,fx,fy),W=W,H=H,holo=holo,tunnel=tun)
        img=Image.eval(img,lambda v:int(v*fade))
        fl=ss(0.84,0.91,t); m=ss(0.91,1.0,t)
        if fl>0 or m>0:
            yy,xx=np.mgrid[0:H,0:W]; rr=np.sqrt(((xx-W/2)/(W/2))**2+((yy-H/2)/(H/2*0.9))**2)
            rad=max(0.05,fl*1.25)
            g=np.clip(1-rr/rad,0,1)**1.4
            col=np.stack([g*225,g*250,g*255],-1).astype(np.uint8)
            bloom=Image.fromarray(col)
            img=ImageChops.lighter(img,bloom)
            if m>0:
                menu=F.menu_frame(W,H).resize((W,H))
                k=(1-m)**1.5
                r,g,b=img.split()
                img=Image.merge("RGB",(r.point(lambda v:int(v*k**3)),g.point(lambda v:int(v*k**1.6)),b.point(lambda v:int(v*k))))
                img=ImageChops.add(img,Image.eval(menu,lambda v:int(v*m)))
        frames.append(img.convert("P",palette=Image.ADAPTIVE))
    frames+= [frames[-1]]*20
    frames[0].save(f"anim_{kind}_{'holo' if holo else 'wire'}.gif",save_all=True,append_images=frames[1:],duration=70,loop=0)
if len(sys.argv)>3:
    TS=[float(x) for x in sys.argv[3].split(",")]
    import face
    _save=Image.Image.save
    out=[]
    D=None
    def seqshot(kind,holo):
        global TS
        pass
    n=len(TS)
    # render and tile
    import builtins
    frames=[]
    orig=Image.Image.convert
    seq.__globals__["TS"]=TS
    res=[]
    def cap(self,*a,**k):
        res.append(self.copy()); return orig(self,*a,**k)
    Image.Image.convert=cap
    try: seq(sys.argv[1],sys.argv[2]=="holo",n=n)
    except Exception as e: pass
    Image.Image.convert=orig
    sh=Image.new("RGB",(480*4,360*((n+3)//4)))
    for j,im in enumerate(res[:n]): sh.paste(im,(480*(j%4),360*(j//4)))
    sh.save(sys.argv[4])
else:
    seq(sys.argv[1],sys.argv[2]=="holo",n=int(__import__("os").environ.get("FRAMES","120")))
