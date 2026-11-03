import json, math, sys
import numpy as np
from scipy.spatial import Delaunay, cKDTree
from PIL import Image, ImageDraw, ImageFilter, ImageChops
CX=500.0
def catmull(pts,n=6,closed=False):
    P=[pts[-1]]+pts+[pts[0],pts[1]] if closed else [pts[0]]+pts+[pts[-1]]
    out=[]
    for i in range(1,len(P)-2):
        p0,p1,p2,p3=[np.array(P[j],float) for j in (i-1,i,i+1,i+2)]
        for k in range(n):
            t=k/n
            out.append(tuple(0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t**3)))
    if not closed: out.append(tuple(map(float,pts[-1])))
    return out
def mx(pts): return [(2*CX-x,y) for x,y in pts]
def sym(half): return half+[(2*CX-x,y) for x,y in reversed(half[1:-1])]
def pip(pt,poly):
    x,y=pt; ins=False; n=len(poly)
    for i in range(n):
        x1,y1=poly[i]; x2,y2=poly[(i+1)%n]
        if (y1>y)!=(y2>y) and x<(x2-x1)*(y-y1)/(y2-y1)+x1: ins=not ins
    return ins

def design(kind):
    F={}
    if kind=="human":
        head=[(500,95),(590,105),(665,150),(712,230),(728,330),(724,430),(745,450),(752,520),(728,590),(705,600),(690,680),(650,770),(590,850),(535,885),(500,890)]
        eye=[(548,478),(575,462),(612,456),(648,466),(668,482),(640,494),(600,498),(568,492)]
        lid=[(542,466),(578,436),(620,428),(660,442),(680,470)]
        brow=[(530,430),(575,412),(630,410),(685,428),(710,450)]
        iris=((608,477),17)
        nose=[(500,470),(505,560),(512,640)]
        nose_side=[(530,500),(540,610),(552,660),(530,680)]
        nostril=[(512,676),(530,680),(548,670)]
        cheek=[(715,540),(660,590),(600,620)]
        philtrum=[(510,688),(512,712)]
        lip_up=[(425,738),(462,722),(492,716),(500,720),(508,716),(538,722),(575,738)]
        lip_lo=[(425,738),(462,762),(500,772),(538,762),(575,738)]
        in_up=[(432,740),(470,736),(500,738),(530,736),(568,740)]
        in_lo=[(432,740),(470,744),(500,746),(530,744),(568,740)]
        chin=[(460,835),(500,848),(540,835)]
        jaw=[(705,600),(680,700),(620,800)]
        ear=[(728,430),(760,445),(766,520),(745,585),(722,590)]
        temple=[(712,250),(680,350),(705,430)]
        fore=None
        smile=[(600,640),(620,700),(600,760)]
        mouth_y=740; drop=120
    else:
        head=[(500,60),(600,75),(690,130),(748,225),(762,325),(810,370),(778,425),(748,515),(736,600),(700,700),(640,800),(572,880),(500,912)]
        eye=[(552,470),(600,438),(668,425),(724,445),(704,486),(640,503),(584,495)]
        lid=[(545,455),(600,418),(672,404),(735,430)]
        brow=[(540,408),(610,378),(690,372),(760,400)]
        iris=((645,463),24)
        nose=[(500,430),(500,560),(500,640)]
        nose_side=[(520,560),(526,630),(518,655)]
        nostril=[(510,652),(528,668)]
        cheek=[(745,560),(660,605),(590,645)]
        philtrum=[(500,660),(500,700)]
        lip_up=[(405,724),(452,700),(500,710),(548,700),(595,724)]
        lip_lo=[(405,724),(452,754),(500,764),(548,754),(595,724)]
        in_up=[(414,726),(458,718),(500,722),(542,718),(586,726)]
        in_lo=[(414,726),(458,730),(500,732),(542,730),(586,726)]
        chin=[(465,845),(500,858),(535,845)]
        jaw=[(736,600),(650,790),(575,872)]
        ear=[(762,325),(810,370),(778,425)]
        temple=[(748,240),(700,330),(640,385)]
        fore=[(545,95),(590,215),(572,345)]
        smile=[(590,645),(610,700),(600,740)]
        mouth_y=726; drop=160
    contour=catmull(sym(head),5,True)
    e=catmull(eye,4,True)
    F["contour"]=contour+[contour[0]]
    for side,f in (("r",lambda p:p),("l",mx)):
        F["eye_"+side]=f(e)+[f(e)[0]]
        F["lid_"+side]=f(catmull(lid,5)); F["brow_"+side]=f(catmull(brow,5))
        F["nose_"+side]=f(catmull(nose_side,4)); F["nostril_"+side]=f(nostril)
        F["cheek_"+side]=f(catmull(cheek,5)); F["jaw_"+side]=f(catmull(jaw,5))
        F["ear_"+side]=f(catmull(ear,4)); F["temple_"+side]=f(catmull(temple,5))
        if fore: F["fore_"+side]=f(catmull(fore,5))
        F["smile_"+side]=f(catmull(smile,4))
    F["nose"]=catmull(nose,4); F["philtrum"]=philtrum
    F["lip_up"]=catmull(lip_up,4); F["lip_lo"]=catmull(lip_lo,4)
    F["in_up"]=catmull(in_up,4); F["in_lo"]=catmull(in_lo,4); F["chin"]=catmull(chin,4)
    eyes=(e,mx(e))
    irises=(iris,((2*CX-iris[0][0],iris[0][1]),iris[1]))
    return dict(kind=kind,F=F,contour=contour,eyes=eyes,irises=irises,mouth_y=mouth_y,drop=drop)

def weights(D,x,y):
    my=D["mouth_y"]; lat=abs(x-CX); hw=D.get("mouth_hw",85.0)
    jw=0.0
    if y>=my-1:
        lips=math.sqrt(max(0.0,1-(lat/hw)**2))            # oval opening at the lip line
        jaw=max(0.0,min(1.0,(215-lat)/95))                  # rigid jaw, stretching cheeks
        jaw=jaw*jaw*(3-2*jaw)
        t=max(0.0,min(1.0,(y-my)/45)); t=t*t*(3-2*t)
        jw=lips*(1-t)+jaw*t
        jw*=max(0,min(1,(y-my+3)/8))
    uw=0.0
    if y<my-1:
        uw=math.sqrt(max(0.0,1-(lat/(hw*1.05))**2))*max(0,1-(my-y)/50)
    return jw,uw
def pose(D,p,o):
    x,y=p; jw,uw=weights(D,x,y)
    y2=y+D["drop"]*o*jw-22*o*uw
    lat=x-CX; c=max(0,1-abs(abs(lat)-75)/55)*max(0,1-abs(y-D["mouth_y"])/30)
    x2=x+(math.copysign(12*o*c,lat) if lat else 0)
    return (x2,y2)

def height(D,x,y):
    # pseudo depth for shading: ellipsoid + features
    nx=(x-CX)/270; ny=(y-480)/430
    z=math.sqrt(max(0.0,1-nx*nx-ny*ny))
    z+=0.18*math.exp(-((x-CX)/22)**2-((y-580)/90)**2)       # nose
    for s in (1,-1):
        ex=CX+s*110
        z-=0.12*math.exp(-((x-ex)/70)**2-((y-470)/40)**2)    # sockets
        z+=0.08*math.exp(-((x-ex)/90)**2-((y-415)/20)**2)    # brow
        z+=0.07*math.exp(-((x-CX-s*170)/60)**2-((y-570)/50)**2) # cheekbones
    z+=0.06*math.exp(-((x-CX)/90)**2-((y-850)/30)**2)
    return z

def build(D,seed=3):
    rng=np.random.default_rng(seed)
    V=[]
    for k,pl in D["F"].items():
        V+=list(pl[::2])+[pl[-1]]
    V=np.array(V)
    # dedupe
    t=cKDTree(V); keep=np.ones(len(V),bool)
    for i,j in sorted(t.query_pairs(11)):
        if keep[i] and keep[j]: keep[j]=False
    V=V[keep]
    pts=[]
    for sp,box in ((58,(220,40,790,940)),(34,(360,380,640,800))):
        xs=np.arange(box[0],box[2],sp); ys=np.arange(box[1],box[3],sp*0.866)
        for r,y in enumerate(ys):
            for x in xs:
                pts.append((x+(sp/2 if r%2 else 0)+rng.uniform(-.3,.3)*sp, y+rng.uniform(-.3,.3)*sp))
    pts=np.array(pts)
    inside=np.array([pip(p,D["contour"]) and not pip(p,D["eyes"][0]) and not pip(p,D["eyes"][1]) for p in pts])
    pts=pts[inside]
    d,_=cKDTree(V).query(pts); pts=pts[d>16]
    t2=cKDTree(pts); keep=np.ones(len(pts),bool)
    for i,j in sorted(t2.query_pairs(20)):
        if keep[i] and keep[j]: keep[j]=False
    V=np.vstack([V,pts[keep]])
    OP=np.array([pose(D,p,1.0) for p in V])
    tri=Delaunay(OP)
    hole=[pose(D,p,1.0) for p in D["F"]["in_up"]+list(reversed(D["F"]["in_lo"]))]
    T=[]
    for s in tri.simplices:
        c=V[s].mean(0); co=OP[s].mean(0)
        if not pip(c,D["contour"]): continue
        if pip(co,hole): continue
        if pip(c,D["eyes"][0]) or pip(c,D["eyes"][1]): continue
        a,b,cc=OP[s]
        if abs(np.cross(b-a,cc-a))/2<12: continue
        ra,rb,rc=V[s]
        if max(np.linalg.norm(ra-rb),np.linalg.norm(rb-rc),np.linalg.norm(rc-ra))>130: continue
        T.append([int(i) for i in s])
    E=sorted({tuple(sorted((t[i],t[(i+1)%3]))) for t in T for i in range(3)})
    return V,T,E

# ------------- rendering -------------
CY=(200,250,255); CYH=(0,170,255); TEAL=(0,255,210)
def glow(img,blurs=((2,1.0),(7,0.9),(22,0.7))):
    out=img.copy()
    for r,a in blurs:
        g=img.filter(ImageFilter.GaussianBlur(r))
        if a!=1.0: g=Image.eval(g,lambda v:int(v*a))
        out=ImageChops.add(out,g)
    return out
def tunnel_layer(D,P,mc,msz,tunnel,size,SS):
    """3D faceted throat. Camera flies forward along +z; walls are a wobbly
    9-sided tube triangulated into facets, fogged by depth."""
    W,H=size
    lay=Image.new("RGB",size,(0,0,0)); d=ImageDraw.Draw(lay,"RGBA")
    c0=np.array(P(tuple(mc))); sx=abs(P((mc[0]+msz[0],mc[1]))[0]-c0[0]); sy=abs(P((mc[0],mc[1]+msz[1]))[1]-c0[1])
    # blend tunnel centre from mouth centre to screen centre as we go inside
    inside=min(1.0,max(0.0,(sx-W*0.35)/(W*0.4)))
    cen=c0*(1-inside)+np.array([W/2,H/2])*inside
    fx=sx*(1-inside)+W*0.42*inside; fy=sy*(1-inside)+W*0.32*inside
    SIDES=16; DZ=0.45; NR=56
    cam=tunnel*float(__import__('os').environ.get('TUNNEL_LEN','40'))                      # distance travelled
    k0=int(math.floor(cam/DZ))+1
    def wob(k,i):
        h=math.sin(k*1.7+i*2.3)*0.5+math.sin(k*0.61+i*4.1)*0.5
        return 1.0+0.13*h
    def bend(z):                          # gentle curving throat
        return 0.55*math.sin(z*0.09), 0.35*math.sin(z*0.07+1.3)
    def proj(k,i):
        z=k*DZ; dz=z-cam
        if dz<0.25: dz=0.25
        bx,by=bend(z); cbx,cby=bend(cam+0.5)
        a=2*math.pi*i/SIDES+k*0.08
        r=wob(k,i)
        x=(math.cos(a)*r+bx-cbx)/dz; y=(math.sin(a)*r*0.82+by-cby)/dz
        return (cen[0]+x*fx, cen[1]+y*fy), dz
    rings=[[proj(k,i) for i in range(SIDES)] for k in range(k0,k0+NR)]
    def fog(dz): return max(0.0,1-(dz/(NR*DZ)))**1.6*min(1.0,(dz-0.2)/2.2)
    # far to near: facets then edges
    for r in range(NR-2,-1,-1):
        A=rings[r]; B=rings[r+1]; k=k0+r
        for i in range(SIDES):
            j=(i+1)%SIDES
            f=fog(A[i][1])
            shade=0.5+0.5*math.sin(i*1.9+k*0.7)
            fillc=(int(1+3*shade*f),int(3+12*shade*f),int(6+20*shade*f),255)
            tri1=[A[i][0],B[i][0],B[j][0]]; tri2=[A[i][0],B[j][0],A[j][0]]
            d.polygon(tri1,fill=fillc); d.polygon(tri2,fill=tuple(int(v*0.82) for v in fillc[:3])+(255,))
            e=(int(70*f),int(190*f),int(235*f),255)
            d.line([A[i][0],B[i][0]],fill=e,width=SS)
            d.line([A[i][0],B[j][0]],fill=tuple(int(v*0.35) for v in e[:3])+(255,),width=SS)
        ring=[p for p,_ in A]
        # travelling power pulses every 6 rings
        ph=(k*DZ+cam*0.6)%5.0
        pulse=max(0.0,1-abs(ph-2.5)/0.6)
        f=fog(A[0][1])
        col=(int((60+195*pulse)*f),int((150+105*pulse)*f),int((200+55*pulse)*f),255)
        d.line(ring+[ring[0]],fill=col,width=SS*(1+int(3*pulse)))
    # light at the end: bright core that swells in the last 35%
    end=max(0.0,(tunnel-0.7)/0.3)
    ec=rings[-1]; ecx=sum(p[0] for p,_ in ec)/SIDES; ecy=sum(p[1] for p,_ in ec)/SIDES
    core=Image.new("RGB",size); dc=ImageDraw.Draw(core)
    R=(5+end**3*W*0.8)
    for m,col in ((1.0,(8,40,60)),(0.6,(30,120,170)),(0.35,(120,215,245)),(0.18,(225,250,255))):
        rr=R*m; dc.ellipse([ecx-rr,ecy-rr*0.8,ecx+rr,ecy+rr*0.8],fill=col)
    core=core.filter(ImageFilter.GaussianBlur(6+50*end))
    lay=ImageChops.lighter(lay,core)
    # speed streaks
    rng=np.random.default_rng(int(tunnel*1000))
    ds=ImageDraw.Draw(lay)
    for _ in range(int(6+18*tunnel)):
        a=rng.uniform(0,2*math.pi); r0=rng.uniform(0.15,0.9); L=rng.uniform(0.05,0.25)*(0.5+tunnel)
        p0=(ecx+math.cos(a)*r0*W*0.5,ecy+math.sin(a)*r0*H*0.5); p1=(ecx+math.cos(a)*(r0+L)*W*0.5,ecy+math.sin(a)*(r0+L)*H*0.5)
        ds.line([p0,p1],fill=(70,170,210),width=SS)
    lay=ImageChops.lighter(lay,lay.filter(ImageFilter.GaussianBlur(6)))
    return lay

def render(D,V,T,E,o,cam,W=960,H=720,holo=False,tunnel=0.0,label="",
           yaw=0.0,roll=0.0,eyes=(1.0,1.0),gaze=0.0):
    SS=2; size=(W*SS,H*SS)
    zoom,fx,fy=cam
    base=min(W,H)/1000*0.92
    def P(p):
        x,y=p; s=base*zoom
        for eye,((ex,ey),_) in zip(eyes,D["irises"]):
            weight=math.exp(-((x-ex)/78)**4-((y-ey)/46)**4)
            y=ey+(y-ey)*(1-(1-eye)*weight)
        depth=height(D,x,y)*190
        x=CX+(x-CX)*math.cos(yaw)+depth*math.sin(yaw)
        dx,dy=x-CX,y-490
        x=CX+dx*math.cos(roll)-dy*math.sin(roll)
        y=490+dx*math.sin(roll)+dy*math.cos(roll)
        return ((x-fx)*s+W/2)*SS,((y-fy)*s+H/2)*SS
    PV=[pose(D,tuple(v),o) for v in V]; S=[P(p) for p in PV]
    mouth=[pose(D,p,o) for p in D["F"]["in_up"]+list(reversed(D["F"]["in_lo"]))]
    ma=np.array(mouth); mc=ma.mean(0); msz=(np.ptp(ma[:,0])/2,max(8,np.ptp(ma[:,1])/2))
    fill=Image.new("RGB",size,(0,0,0)); df=ImageDraw.Draw(fill)
    L=np.array([-0.45,-0.55,0.7]); L/=np.linalg.norm(L)
    if holo:
        for t in T:
            a,b,c=[np.array([PV[i][0],PV[i][1],height(D,*V[i])*300]) for i in t]
            n=np.cross(b-a,c-a); n/=np.linalg.norm(n)+1e-9
            if n[2]<0: n=-n
            sh=max(0,float(n@L))**2
            df.polygon([S[i] for i in t],fill=(int(2+16*sh),int(14+70*sh),int(28+95*sh)))
    lines=Image.new("RGB",size,(0,0,0)); dl=ImageDraw.Draw(lines)
    for a,b in E:
        lum=0.35+0.65*min(1,(height(D,*V[a])+height(D,*V[b]))/2)
        col=(int(110*lum),int(200*lum),int(235*lum)) if not holo else (int(60*lum),int(220*lum),int(255*lum))
        dl.line([S[a],S[b]],fill=col,width=SS)
    for k,pl in D["F"].items():
        w=SS*(3 if k in("contour","lip_up","lip_lo","eye_r","eye_l") else 2)
        dl.line([P(pose(D,p,o)) for p in pl],fill=(225,250,255),width=w)
    for eye,(c,r) in zip(eyes,D["irises"]):
        if eye<0.08: continue
        for rr,ww in ((r,2),(r*0.42,3)):
            ring=[P((c[0]+gaze+rr*math.cos(a),c[1]+rr*math.sin(a))) for a in np.linspace(0,2*math.pi,49)]
            dl.line(ring,fill=(150,255,235) if D["kind"]=="alien" else (230,255,255),width=SS*ww)
    face=ImageChops.add(fill,lines)
    if holo:
        scan=Image.new("L",size,255); ds=ImageDraw.Draw(scan)
        for y in range(0,size[1],4*SS): ds.line([(0,y),(size[0],y)],fill=150,width=SS)
        face=Image.composite(face,Image.new("RGB",size),scan)
    if o>0.05:
        tl=tunnel_layer(D,P,mc,msz,tunnel,size,SS)
        mask=Image.new("L",size,0); ImageDraw.Draw(mask).polygon([P(p) for p in mouth],fill=255)
        if zoom>=60: mask=Image.new("L",size,255)
        face=Image.composite(tl,face,mask) if True else face
        # keep lip lines on top
        lip=Image.new("RGB",size); dlp=ImageDraw.Draw(lip)
        for k in ("in_up","in_lo"):
            dlp.line([P(pose(D,p,o)) for p in D["F"][k]],fill=(225,250,255),width=SS*3)
        face=ImageChops.lighter(face,lip)
    img=face.resize((W,H),Image.LANCZOS)
    img=glow(img,((2,0.8),(7,0.6),(22,0.45)))
    if label: ImageDraw.Draw(img).text((12,H-22),label,fill=(90,140,160))
    return img

def menu_frame(W=960,H=720,fade=1.0,tunnel=1.0):
    W,H=960,720
    img=Image.new("RGB",(W,H)); d=ImageDraw.Draw(img)
    cx,cy=W/2,H/2
    for k in range(12):
        depth=(k+(1-(tunnel*10)%1))/12; r=(1-depth)**3*900+6
        a=depth*2.2+tunnel*2
        pts=[(cx+math.cos(a+2*math.pi*i/9)*r,cy+math.sin(a+2*math.pi*i/9)*r*0.75) for i in range(9)]
        lum=0.18*(1-depth)
        d.line(pts+[pts[0]],fill=(int(160*lum),int(240*lum),int(255*lum)),width=2)
    try:
        from PIL import ImageFont
        big=ImageFont.truetype("DejaVuSans-Bold.ttf",54); sm=ImageFont.truetype("DejaVuSans.ttf",22); it=ImageFont.truetype("DejaVuSans-Bold.ttf",26)
    except Exception:
        big=sm=it=None
    def ctext(y,t,f,c):
        w=d.textlength(t,font=f); d.text((cx-w/2,y),t,font=f,fill=tuple(int(v*fade) for v in c))
    ctext(150,"ASH MERIDIAN",big,(115,235,255)); ctext(220,"NARCEA",sm,(205,90,165))
    for i,t in enumerate(("PLAY","OPTIONS","EXIT")):
        ctext(330+i*56,("> " if i==0 else "")+t,it,(235,250,255) if i==0 else (120,170,185))
    ctext(640,"UP / DOWN     ENTER     MOUSE",ImageFont.truetype("DejaVuSans.ttf",14) if sm else None,(100,125,135))
    return glow(img,((2,0.6),(8,0.4)))

def mouth_center(D,o=1.0):
    ma=np.array([pose(D,p,o) for p in D["F"]["in_up"]+list(reversed(D["F"]["in_lo"]))]); return ma.mean(0)

if __name__=="__main__":
    out=sys.argv[1]
    for kind in ("human","alien"):
        D=design(kind); V,T,E=build(D)
        print(kind,"verts",len(V),"tris",len(T),"edges",len(E))
        json.dump({"verts":V.round(1).tolist(),"tris":T,"edges":E},open(f"{out}/{kind}_mesh.json","w"))
        my=D["mouth_y"]
        for holo in (False,True):
            tag=f"{kind}_{'holo' if holo else 'wire'}"
            render(D,V,T,E,0.0,(1.0,500,490),holo=holo,label=tag+"  assembled").save(f"{out}/{tag}_1_face.png")
            render(D,V,T,E,1.0,(1.15,500,560),holo=holo,label=tag+"  mouth open").save(f"{out}/{tag}_2_open.png")
            mc=mouth_center(D)
            render(D,V,T,E,1.0,(3.2,mc[0],mc[1]),holo=holo,tunnel=0.25,label=tag+"  zoom into mouth").save(f"{out}/{tag}_3_zoom.png")
            render(D,V,T,E,1.0,(9.0,mc[0],mc[1]),holo=holo,tunnel=0.6,label=tag+"  inside tunnel").save(f"{out}/{tag}_4_tunnel.png")
            render(D,V,T,E,1.0,(14.0,mc[0],mc[1]),holo=holo,tunnel=0.93,label=tag+"  tunnel end -> menu").save(f"{out}/{tag}_5_end.png")
            menu_frame().save(f"{out}/{tag}_6_menu.png")
