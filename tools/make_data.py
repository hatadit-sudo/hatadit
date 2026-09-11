import json
from pathlib import Path
buildings={
'house':dict(name='Longhouse',shape=[[0,0],[1,0],[0,1]],cost={'wood':5,'stone':1},hp=38,block=True,wooden=True,desc='+1 resident. Well: +1 morale; adjacent home: +1 food. Forge: -1 morale.'),
'farm':dict(name='Cropland',shape=[[0,0],[1,0],[2,0]],cost={'wood':2},hp=20,block=False,wooden=False,desc='+4 food. River +2, pasture +2. Passable; slows invaders. Winter yield halved.'),
'lumber':dict(name='Timber yard',shape=[[0,0],[1,0],[1,1]],cost={'wood':4,'stone':1},hp=32,block=True,wooden=True,desc='+3 wood; next to woodland +2 wood. Uses three cells.'),
'smith':dict(name='Forge',shape=[[0,0],[1,0]],cost={'wood':4,'stone':3,'iron':1},hp=45,block=True,wooden=True,desc='+1 iron; high ground +1. Warehouse: training costs 1 less iron. Noisy near homes.'),
'well':dict(name='Well',shape=[[0,0]],cost={'stone':3},hp=50,block=True,wooden=False,desc='Protects adjacent buildings from fire. Homes gain morale; pasture causes -2 morale.'),
'pasture':dict(name='Sheep pen',shape=[[0,0],[1,0],[0,1],[1,1]],cost={'wood':4,'food':2},hp=25,block=False,wooden=True,desc='+3 food. Fertilizes adjacent fields. Sheep contaminate adjacent wells.'),
'warehouse':dict(name='Storehouse',shape=[[0,0],[0,1]],cost={'wood':4,'stone':2},hp=42,block=True,wooden=True,desc='+1 silver. Improves trade; reduces adjacent forge training costs. Raiders target it.'),
 'tower':dict(name='Watchtower',shape=[[0,0]],cost={'wood':5,'stone':3},hp=55,block=True,wooden=True,desc='Automatic bow defense. Range 4; on high ground range 6.'),
'wall':dict(name='Palisade',shape=[[0,0],[1,0]],cost={'wood':3,'stone':1},hp=65,block=True,wooden=True,desc='Blocks movement; connected wall sections add 10 HP when placed.'),
'hall':dict(name='Great hall',shape=[[0,0],[1,0],[0,1],[1,1]],cost={},hp=150,block=True,wooden=True,desc='Protect the hearth. Losing the great hall ends the session.')}
units={
'shield':dict(name='Shield',hp=55,damage=7,range=1,reload=2,armor=3,cost={'food':2,'wood':2,'iron':1},desc='Holds its tile. Strong armor and high health.'),
'spear':dict(name='Spear',hp=34,damage=11,range=2,reload=2,armor=1,cost={'food':2,'wood':2,'iron':2},desc='Holds formation. Strikes up to two cells in a straight line.'),
'archer':dict(name='Archer',hp=24,damage=9,range=4,reload=3,armor=0,cost={'food':2,'wood':3,'iron':1},desc='Picks vulnerable ranged enemies first; high ground +2 range.'),
'cavalry':dict(name='Rider',hp=43,damage=12,range=1,reload=2,armor=1,cost={'food':4,'wood':2,'iron':3},desc='Pursues enemies. Three straight steps give a double-damage charge.'),
'cannon':dict(name='Bombard',hp=36,damage=27,range=6,reload=6,armor=1,cost={'wood':5,'iron':5,'silver':2},desc='Slow reload. Requires a straight firing lane; splash hits neighboring enemies.'),
'raider':dict(name='Raider',hp=25,damage=6,range=1,reload=2,armor=0,speed=1,desc='Targets storehouses before the great hall.'),
'heavy':dict(name='Huscarl',hp=58,damage=10,range=1,reload=3,armor=4,speed=2,desc='Heavy armor resists arrows.'),
'enemy_archer':dict(name='Enemy bow',hp=22,damage=7,range=3,reload=3,armor=0,speed=2,desc='Shoots from behind the front line.'),
'sapper':dict(name='Sapper',hp=36,damage=17,range=1,reload=3,armor=1,speed=2,desc='Prioritizes walls and deals double damage to them.'),
'firebrand':dict(name='Firebrand',hp=28,damage=6,range=1,reload=2,armor=0,speed=2,desc='Ignites wooden buildings. Dense construction spreads fire.')}
waves={'3':{'side':'east','units':['raider']*4+['enemy_archer']},'5':{'side':'north','units':['heavy']*2+['raider']*3+['sapper','enemy_archer']},'8':{'side':'east','units':['heavy']*3+['sapper']*2+['firebrand']*2+['enemy_archer']*2},'10':{'side':'both','units':['heavy']*4+['raider']*5+['sapper']*2+['firebrand']*3+['enemy_archer']*3}}
Path(__file__).resolve().parents[1].joinpath('data.json').write_text(json.dumps({'buildings':buildings,'units':units,'waves':waves},indent=2))
