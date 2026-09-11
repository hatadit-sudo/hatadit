"""Original deterministic raster sprites. No third-party game assets.
Run with Python 3 + Pillow. Pixels are drawn at native resolution.
"""
from PIL import Image, ImageDraw
from pathlib import Path
import random, math, wave, struct
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets'; OUT.mkdir(exist_ok=True)
rng=random.Random(713)
P={'ink':'#202e31','wood':'#79533c','light':'#b88b56','dark':'#49392e','roof':'#506a70','edge':'#314a52','gold':'#e9bd6b','grass':'#638567'}
def canvas(w=96,h=112):
    im=Image.new('RGBA',(w,h)); return im,ImageDraw.Draw(im)
def save(im,name): im.save(OUT/(name+'.png'))
def poly(d,pts,fill,outline=P['ink']): d.polygon(pts,fill=fill); d.line(pts+[pts[0]],fill=outline,width=1)
def box(d,x,y,w,h,front=P['wood'],side=P['dark']):
    poly(d,[(x,y),(x+w,y-w//2),(x+w,y-w//2+h),(x,y+h)],front)
    poly(d,[(x,y),(x-w,y-w//2),(x-w,y-w//2+h),(x,y+h)],side)
    poly(d,[(x-w,y-w//2),(x,y-w),(x+w,y-w//2),(x,y)],P['light'])
def barrel(d,x,y):
    d.rounded_rectangle((x-4,y-9,x+4,y),2,fill=P['wood'],outline=P['ink'])
    d.line((x-4,y-6,x+4,y-6),fill=P['light']); d.line((x-4,y-2,x+4,y-2),fill='#313d3d')
def hut(kind):
    im,d=canvas(); d.ellipse((18,76,82,105),fill=(18,29,27,75))
    if kind=='tower':
        for x in (32,62): d.rectangle((x,34,x+5,87),fill=P['dark']); d.line((x,36,x,85),fill=P['light'],width=2)
        d.line((35,75,62,44),fill=P['wood'],width=4); d.line((35,44,62,75),fill=P['wood'],width=4)
        box(d,49,32,24,12)
        for x in range(25,74,6): d.rectangle((x,22,x+3,33),fill=P['light'],outline=P['ink'])
        d.line((49,20,49,1),fill=P['dark'],width=2); poly(d,[(50,2),(70,6),(50,13)],'#ba604a')
        d.line((53,42,53,90),fill=P['light'],width=2); d.line((62,39,62,85),fill=P['light'],width=2)
        for y in range(44,87,6): d.line((53,y+3,62,y),fill=P['wood'],width=2)
    elif kind=='well':
        box(d,48,79,19,11, '#85948a','#505e60')
        poly(d,[(32,72),(48,63),(63,72),(48,81)],'#1b3943')
        for x in (29,65): d.rectangle((x,40,x+3,77),fill=P['wood'])
        poly(d,[(22,42),(47,22),(74,39),(47,54)],P['roof']); d.line((48,48,48,76),fill='#d2ad72')
        barrel(d,64,94)
    elif kind=='wall':
        for i in range(7):
            x=24+i*7; y=75-abs(i-3)*3
            poly(d,[(x,y),(x,y-29),(x+3,y-35),(x+6,y-30),(x+6,y)],P['light'] if i%2 else P['wood'])
        d.line((24,67,46,77,71,66),fill=P['dark'],width=3)
    elif kind=='farm':
        poly(d,[(7,79),(48,58),(89,79),(48,100)],'#745640')
        for j in range(5):
            for i in range(7):
                x=20+i*6+j*4; y=81+i*3-j*5
                d.line((x,y,x,y-7),fill='#b9bc62'); d.line((x,y-3,x-3,y-6),fill='#dad081'); d.point((x+2,y-6),fill='#edda95')
        d.rectangle((24,68,26,79),fill=P['wood']); d.line((19,71,31,71),fill=P['wood'],width=2)
    elif kind=='pasture':
        poly(d,[(9,78),(47,59),(87,79),(48,100)],'#7e9866')
        for a,b in [((10,78),(48,97)),((48,97),(86,78))]:
            d.line((a,b),fill=P['light'],width=2)
            for k in range(5):
                x=int(a[0]+(b[0]-a[0])*k/4); y=int(a[1]+(b[1]-a[1])*k/4)
                d.line((x,y+3,x,y-9),fill=P['dark'],width=2)
        for x,y in [(37,77),(60,82)]:
            d.ellipse((x-7,y-5,x+6,y+3),fill='#e5d7b7',outline=P['ink']); d.rectangle((x+4,y-2,x+9,y+3),fill='#615142')
            d.line((x-4,y+2,x-4,y+6),fill=P['ink']); d.line((x+4,y+2,x+4,y+6),fill=P['ink'])
    else:
        w=26 if kind!='hall' else 33
        box(d,48,67,w,26)
        for yy in range(69,90,5):
            d.line((48-w,yy-w//2,48,yy,48+w,yy-w//2),fill='#906a48')
        for x,y in [(29,67),(57,70)]:
            d.rectangle((x,y,x+8,y+10),fill=P['dark'],outline=P['ink']); d.rectangle((x+2,y+2,x+6,y+7),fill='#edb76a')
        poly(d,[(14,53),(44,25),(84,47),(51,76)],'#54777c' if kind!='smith' else '#866151')
        poly(d,[(14,53),(44,25),(38,53),(15,66)],'#354c56')
        for j in range(6):
            y=34+j*5; d.line((43,y,76-j*3,y+17),fill='#739192' if kind!='smith' else '#a07c5a')
        d.line((44,25,84,47),fill='#b18c5a',width=3)
        d.line((42,24,39,18,34,19),fill=P['light'],width=2); d.line((83,46,90,40,92,43),fill=P['light'],width=2)
        poly(d,[(42,90),(42,76),(50,79),(50,94)],P['ink'])
        barrel(d,70,94); barrel(d,78,89)
        if kind=='smith':
            box(d,63,37,6,20,'#777d73','#525956'); d.rectangle((60,31,67,35),fill='#23373c')
            box(d,22,91,7,5,'#536570','#354452'); d.rectangle((15,85,30,89),fill='#94a1a1')
            d.rectangle((58,80,65,86),fill='#e78d43'); d.rectangle((59,83,62,86),fill='#ffe59c')
        if kind=='lumber':
            for j in range(3):
                d.line((13,89+j*4,31,98+j*3),fill=P['wood'],width=4); d.ellipse((10,87+j*4,16,92+j*4),fill=P['light'],outline=P['dark'])
            d.line((74,75,79,65),fill=P['wood'],width=2); d.rectangle((76,62,83,67),fill='#acb8b2')
        if kind=='warehouse':
            for x,y in [(18,90),(25,96),(68,100)]: box(d,x,y,6,7)
        if kind=='hall':
            d.line((78,72,78,18),fill=P['dark'],width=2); poly(d,[(79,19),(94,23),(91,38),(79,34)],'#b65441')
            d.line((82,24,88,31),fill=P['gold'],width=2)
    return im
for k in ['house','hall','farm','lumber','smith','well','pasture','warehouse','tower','wall']: save(hut(k),k)
# Terrain diamonds with dirt edging and seeded fine texture, 64x40.
for kind,base in [('grass','#648366'),('high','#7d876c'),('river','#3f747c'),('road','#9a8a65'),('snow','#b4c4b8')]:
    for v in range(4):
        im,d=canvas(64,40)
        poly(d,[(0,17),(32,1),(63,17),(63,23),(32,39),(0,23)],'#415749')
        poly(d,[(0,17),(32,1),(63,17),(32,33)],base,base)
        for _ in range(55):
            x=rng.randrange(2,62); y=rng.randrange(2,33)
            if abs(x-32)/32+abs(y-17)/16<.93:
                colors=('#52848a','#75a2a0','#356975') if kind=='river' else ('#799270','#4f745d','#93a079') if kind in ['grass','high'] else ('#b8b193','#7d7e67') if kind=='road' else ('#dce1cb','#9dadab')
                d.line((x,y,x+rng.choice([1,2,3]),y),fill=rng.choice(colors))
        save(im,f'{kind}{v}')
# Trees, rocks, log, fire, wildflowers. All proper world sprites.
for kind in ['tree','pine','rock','log','fire','flowers']:
    im,d=canvas(64,88)
    d.ellipse((13,65,54,82),fill=(20,37,35,65))
    if kind in ['tree','pine']:
        d.rectangle((29,40,35,74),fill=P['dark']); d.line((31,44,31,71),fill=P['light'],width=2)
        for j in range(4):
            y=8+j*13; w=10+j*5
            poly(d,[(32,y),(32-w,y+29),(32+w,y+29)],['#30524b','#3d6352','#497758','#5c855c'][j])
            d.line((32,y+3,32-w+5,y+25),fill='#769268')
    elif kind=='rock':
        poly(d,[(16,71),(21,57),(38,51),(49,62),(47,74),(29,81)],'#788985')
        poly(d,[(21,57),(38,51),(39,66),(16,71)],'#a0a79b'); d.line((39,66,47,74),fill='#53696a')
    elif kind=='log':
        d.line((17,66,45,78),fill=P['dark'],width=9); d.line((18,63,45,75),fill=P['wood'],width=5); d.ellipse((12,61,22,72),fill=P['light'],outline=P['dark'])
    elif kind=='fire':
        d.ellipse((17,63,45,79),fill='#5c6662',outline=P['ink']); d.line((23,73,39,68),fill=P['dark'],width=4)
        poly(d,[(22,70),(25,59),(29,62),(33,46),(38,62),(42,68),(35,75)],'#d78345'); poly(d,[(28,70),(32,60),(35,66),(38,70),(33,73)],'#f4d381')
    else:
        for _ in range(10):
            x=rng.randrange(14,48);y=rng.randrange(61,77);d.line((x,y,x,y-4),fill='#769963');d.rectangle((x-1,y-6,x+1,y-4),fill=rng.choice(['#d3bca5','#b7c5a0','#8eb7af']))
    save(im,kind)
# 4 animation frames, 2 facing directions, individually loadable sprite files.
colors={'villager':'#b59364','shield':'#527f8b','spear':'#7b9c92','archer':'#91a370','cavalry':'#5d8892','cannon':'#9c947d','raider':'#b06950','heavy':'#965b53','enemy_archer':'#b1845e','sapper':'#b89965','firebrand':'#c77e4b'}
for kind,col in colors.items():
    for frame in range(4):
        im,d=canvas(48,48);bob=frame%2
        d.ellipse((11,37,35,44),fill=(14,24,27,90))
        if kind=='cannon':
            d.ellipse((11,29,20,41),fill=P['dark'],outline='#bda17a'); d.ellipse((29,24,38,36),fill=P['dark'],outline='#bda17a')
            poly(d,[(16,29),(30,18),(38,23),(24,35)],'#4c6067'); poly(d,[(27,18),(33,14),(42,19),(38,24)],'#809092');d.line((30,18,37,21),fill='#c0c4af',width=2)
        else:
            if kind=='cavalry':
                d.ellipse((9,27,36,38),fill='#795c43',outline=P['ink']); d.rectangle((31,19,37,31),fill='#866b50')
                for x in [13,20,29,34]: d.line((x,35,x+(frame%2)*2,44),fill='#453b34',width=2)
            else:
                for x,phase in [(20,1),(27,-1)]:
                    yy=39+(frame%2)*phase; d.rectangle((x,32,x+3,yy),fill='#3b4140'); d.rectangle((x,yy-1,x+5,yy+1),fill='#312f2c')
            d.rectangle((18,20+bob,29,32+bob),fill=col,outline=P['ink']); d.line((19,29+bob,29,29+bob),fill=P['dark'],width=2)
            d.rectangle((19,10+bob,28,20+bob),fill='#dab78a',outline=P['ink']); d.rectangle((18,9+bob,29,13+bob),fill='#869492' if kind!='villager' else '#6a4e3c')
            d.point((27,15+bob),fill=P['ink']);d.line((22,19+bob,27,21+bob),fill='#876044',width=2)
            d.line((17,23+bob,14,29+bob),fill='#dab78a',width=3)
            if kind in ['shield','heavy']:
                d.ellipse((8,22,21,36),fill=col,outline='#d4b77f'); d.line((14,23,14,35),fill=P['light']); d.rectangle((13,27,16,30),fill='#c3c5b1')
                d.line((33,30,35,15),fill='#c0ccc1',width=2)
            elif kind in ['spear','sapper']:
                d.line((33,38,33,5),fill=P['light'],width=2); poly(d,[(31,9),(33,2),(36,8)],'#d2d7c4')
            elif kind in ['archer','enemy_archer']:
                d.arc((27,15,39,36),270,90,fill='#c6a56a',width=2); d.line((33,15,33,35),fill='#e6d6aa')
            elif kind=='firebrand':
                d.line((34,30,34,14),fill=P['wood'],width=2); poly(d,[(30,15),(33,6),(35,10),(38,5),(38,16)],'#edb459')
            elif kind=='villager':
                d.line((11,27,27,33),fill=P['wood'],width=5);d.ellipse((9,25,15,30),fill=P['light'])
            else: d.line((33,29,37,15),fill='#c0ccc1',width=2)
        save(im,f'{kind}_{frame}')
# Resource sprites.
for name,col in [('food','#d7b169'),('wood','#b88b56'),('stone','#9eaca4'),('iron','#6e929d'),('silver','#d4d6c1')]:
    im,d=canvas(20,20)
    if name=='food':
        d.line((7,17,13,3),fill='#bca36d',width=2)
        for y in range(5,15,3):d.ellipse((5,y,10,y+3),fill=col);d.ellipse((11,y-2,16,y+1),fill=col)
    elif name=='wood':
        d.line((5,5,15,15),fill=P['dark'],width=9);d.line((5,4,15,14),fill=col,width=5);d.ellipse((2,2,9,9),fill='#d1ac77',outline=P['dark'])
    elif name=='silver':d.ellipse((3,3,17,17),fill=col,outline='#7d897e');d.ellipse((6,6,14,14),outline='#8c998a')
    else:poly(d,[(2,13),(6,4),(13,3),(18,11),(13,17),(4,17)],col)
    save(im,'res_'+name)
# Native application icon.
im=Image.new('RGBA',(192,192),'#203d46'); im.alpha_composite(hut('hall').resize((144,168),Image.Resampling.NEAREST),(24,12));save(im,'icon')
# Short original synthesized sound effects.
for name,freq,duration in [('click',650,.08),('place',120,.18),('gain',840,.24),('shot',190,.12),('boom',55,.42),('round',440,.5),('hit',100,.1)]:
    sample=[];randomizer=random.Random(17)
    for i in range(int(22050*duration)):
        t=i/22050;env=(1-t/duration)**2; noise=randomizer.uniform(-1,1)
        v=math.sin(2*math.pi*(freq*t-35*t*t))*env
        if name in ('place','boom','hit','shot'):v=.35*v+.65*noise*env
        if name in ('gain','round'):v=(v+math.sin(2*math.pi*freq*1.5*t)*env)*.5
        sample.append(struct.pack('<h',int(v*12000)))
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setparams((1,2,22050,0,'NONE','not compressed'));w.writeframes(b''.join(sample))
print('Generated',len(list(OUT.glob('*'))),'original art/audio assets')
