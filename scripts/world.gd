extends Node2D
## Pixel world renderer: all rules and hit testing use the same board coordinates.
var model
var sprites: Dictionary = {}
var age: float = 0.0
var hover = Vector2i(-100,-100)
var selection: String = ""
var build_rotation: int = 0
var moving_id: int = -1
var selected_building: int = -1
var show_grid: bool = false
var effects: Array = []
var motions: Dictionary = {}
var flashes: Dictionary = {}
var decorations: Array = []
var render_shake = Vector2.ZERO
var combat_interval: float = 0.48
var font = ThemeDB.fallback_font

func setup(rules) -> void:
	model = rules
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for name in ["house","hall","farm","lumber","smith","well","pasture","warehouse","tower","wall","tree","pine","rock","log","fire","flowers"]:
		sprites[name] = load("res://assets/"+name+".png")
	for kind in ["grass","high","river","road","snow"]:
		for i in range(4): sprites[kind+str(i)] = load("res://assets/"+kind+str(i)+".png")
	for kind in model.data.units.keys()+["villager"]:
		for i in range(4): sprites[kind+"_"+str(i)] = load("res://assets/"+kind+"_"+str(i)+".png")
	var randomizer = RandomNumberGenerator.new()
	randomizer.seed = 4021
	for y in range(-3,13):
		for x in range(-3,13):
			if x >= 0 and x < 10 and y >= 0 and y < 10: continue
			if randomizer.randf() > .65: continue
			var kind = ["pine","tree","rock","flowers"][randomizer.randi_range(0,3)]
			decorations.append({"p":iso(Vector2(x,y))+Vector2(randomizer.randf_range(-8,8),0),"kind":kind})
	model.feedback.connect(on_feedback)

func iso(c: Vector2) -> Vector2:
	return Vector2((c.x-c.y)*32,(c.x+c.y)*16)

func cell_at(screen: Vector2) -> Vector2i:
	var p = to_local(screen)
	return Vector2i(int(floor((p.x/32+p.y/16)*.5+.5)),int(floor((p.y/16-p.x/32)*.5+.5)))

func diamond(p: Vector2, color: Color, outline: bool = false) -> void:
	var points = PackedVector2Array([p+Vector2(-31,0),p+Vector2(0,-15),p+Vector2(31,0),p+Vector2(0,15)])
	if outline:
		points.append(points[0])
		draw_polyline(points,color,1.0)
	else: draw_colored_polygon(points,color)

func _process(delta: float) -> void:
	age += delta
	for fx in effects: fx.t += delta
	effects = effects.filter(func(fx): return fx.t < fx.life)
	for id in motions.keys():
		motions[id].t += delta
		if motions[id].t >= motions[id].duration: motions.erase(id)
	for id in flashes.keys():
		flashes[id] -= delta
		if flashes[id] <= 0: flashes.erase(id)
	queue_redraw()

func on_feedback(kind: String, cell: Vector2i, detail: String) -> void:
	var p = iso(cell)
	match kind:
		"move":
			var parts = detail.split(",")
			motions[int(parts[0])] = {"from":p,"to":iso(Vector2(int(parts[1]),int(parts[2]))),"t":0.0,"duration":combat_interval*.85}
		"projectile":
			var parts = detail.split(",")
			effects.append({"kind":kind,"p":p-Vector2(0,13),"end":iso(Vector2(int(parts[0]),int(parts[1])))-Vector2(0,10),"t":0.0,"life":.24,"detail":parts[2]})
		"place":
			flashes[cell] = .25
			effects.append({"kind":"dust","p":p,"t":0.0,"life":.45,"detail":""})
		"gain": effects.append({"kind":"gain","p":p,"t":0.0,"life":1.1,"detail":detail})
		"round": effects.append({"kind":"season","p":p,"t":0.0,"life":.8,"detail":""})
		_: effects.append({"kind":kind,"p":p,"t":0.0,"life":.48,"detail":detail})

func draw_sprite(kind: String, p: Vector2, tint: Color = Color.WHITE, factor: float = 1.0) -> void:
	if not sprites.has(kind): return
	var tex: Texture2D = sprites[kind]
	var offset = Vector2(tex.get_width()*.5,tex.get_height()-12)*factor
	draw_texture_rect(tex,Rect2((p-offset).round(),Vector2(tex.get_size())*factor),false,tint)

func _draw() -> void:
	if model == null: return
	draw_set_transform(render_shake)
	var winter = model.season() == "WINTER"
	var autumn = model.season() == "AUTUMN"
	for diagonal in range(-6,25):
		for x in range(-3,13):
			var y = diagonal-x
			if y < -3 or y > 12: continue
			var c = Vector2i(x,y)
			var kind: String = model.terrain.get(c,"grass")
			var board = model.inside(c)
			if x == -1 or (x == 0 and not board): kind = "river"
			if winter and kind not in ["river","road"]: kind = "snow"
			var tint = Color.WHITE if board else Color(.63,.76,.73)
			if autumn and kind == "grass": tint = Color(1.1,.93,.74)
			var p = iso(c)
			draw_texture(sprites[kind+str(posmod(x*7+y*11,4))],p-Vector2(32,17),tint)
			if board:
				if kind == "high":
					draw_line(p+Vector2(-25,4),p+Vector2(-10,11),Color("a5aa85"),2)
				if show_grid or selection != "" or moving_id >= 0: diamond(p,Color(.85,.88,.65,.22),true)
				if x == 0 or y == 0 or x == 9 or y == 9: diamond(p,Color(.84,.82,.58,.32),true)
	# Footprints are architecture foundations, visibly different from walkable ground.
	for b in model.buildings:
		for c in b.cells:
			var p = iso(c)
			if b.kind not in ["farm","pasture"]: diamond(p,Color("81755b"))
			if b.id == selected_building: diamond(p,Color("edc779"),true)
	# Paths are existing dirt terrain; constructions physically interrupt them.
	if model.phase in ["planning","preparation"]:
		var next_wave = 10
		for r in [3,5,8,10]:
			if r >= model.round_no: next_wave = r; break
		var side: String = model.data.waves[str(next_wave)].side
		for i in range(2,9,2):
			if side in ["east","both"]: approach_arrow(Vector2i(9,i),Vector2(-10,-5))
			if side in ["north","both"]: approach_arrow(Vector2i(i,0),Vector2(-10,5))
	var entries: Array = []
	for item in decorations: entries.append({"type":"decor","p":item.p,"data":item})
	for b in model.buildings:
		var center = Vector2.ZERO
		for c in b.cells: center += Vector2(c)
		center /= b.cells.size()
		var p = iso(center)
		entries.append({"type":"building","p":p,"data":b})
	for u in model.units+model.enemies:
		var p = iso(u.cell)
		if motions.has(u.id):
			var m = motions[u.id]
			p = m.from.lerp(m.to,clampf(m.t/m.duration,0,1))
		entries.append({"type":"unit","p":p,"data":u})
	if model.phase != "combat":
		for i in range(mini(model.population,10)):
			var route = villager_route(i)
			if route.size() < 2: continue
			var progress = fmod(age*.65+i*1.8,float(route.size()-1)*2)
			if progress > route.size()-1: progress = (route.size()-1)*2-progress
			var index = mini(int(progress),route.size()-2)
			var p = iso(Vector2(route[index]).lerp(Vector2(route[index+1]),fmod(progress,1.0)))
			entries.append({"type":"villager","p":p,"data":i})
	entries.append({"type":"decor","p":iso(Vector2(3,5)),"data":{"kind":"fire"}})
	entries.sort_custom(func(a,b): return a.p.y < b.p.y)
	for entry in entries:
		var p: Vector2 = entry.p
		match entry.type:
			"decor": draw_sprite(entry.data.kind,p)
			"building": render_building(entry.data,p)
			"unit": render_unit(entry.data,p)
			"villager":
				draw_sprite("villager_"+str(int(age*5+entry.data)%4),p)
	if model.inside(hover):
		if selection.begins_with("build:"):
			var kind = selection.trim_prefix("build:")
			var valid = model.placement_error(kind,hover,build_rotation) == ""
			var color = Color(.63,.89,.65,.55) if valid else Color(.91,.36,.28,.55)
			for c in model.footprint(kind,hover,build_rotation): diamond(iso(c),color)
			draw_sprite(kind,iso(hover),Color(1,1,1,.55))
		elif selection.begins_with("train:") or moving_id >= 0:
			diamond(iso(hover),Color(.64,.84,.85,.7))
		else: diamond(iso(hover),Color(1,.89,.65,.65),true)
	for fx in effects: render_effect(fx)
	if winter:
		for i in range(45):
			var x = fmod(i*97.3+sin(age+i)*6,820.0)-410
			var y = fmod(i*53.1+age*13,440.0)-80
			draw_rect(Rect2(Vector2(x,y),Vector2(1,2)),Color(.9,.96,.93,.5))

func approach_arrow(c: Vector2i, direction: Vector2) -> void:
	var p = iso(c)
	var alpha = .55+sin(age*3)*.2
	var color = Color(.92,.55,.35,alpha)
	draw_line(p-direction,p+direction,color,2)
	draw_line(p+direction,p+Vector2(0,-6),color,2)
	draw_line(p+direction,p+Vector2(0,6),color,2)

func villager_route(index: int) -> Array:
	# Only use genuinely passable neighboring tiles: residents cannot walk through homes.
	var starts = [Vector2i(3,4),Vector2i(4,3),Vector2i(6,5),Vector2i(3,7),Vector2i(5,7)]
	var start: Vector2i = starts[index%starts.size()]
	if not model.walkable(start):
		for c in model.terrain:
			if model.walkable(c): start = c; break
	var route: Array = [start]
	var current = start
	for j in range(5):
		var found = false
		for k in range(4):
			var next: Vector2i = current+model.DIRS[(k+j+index)%4]
			if model.walkable(next) and next not in route:
				route.append(next)
				current = next
				found = true
				break
		if not found: break
	return route

func render_building(b: Dictionary,p: Vector2) -> void:
	var tint = Color.WHITE
	if flashes.has(b.cell): p.y -= sin(flashes[b.cell]/.25*PI)*4
	if b.fire > 0: tint = Color(1.2,.75,.6)
	if b.kind in ["farm","pasture","wall"]:
		for c in b.cells: draw_sprite(b.kind,iso(c),tint,.72)
	else:
		draw_sprite(b.kind,p,tint,1.12 if b.kind == "hall" else 1.0)
		# Auxiliary material piles occupy the footprint, rather than a single floating icon.
		if b.cells.size() > 1 and b.kind in ["lumber","warehouse","house"]:
			draw_sprite("log",p+Vector2(-24,9),Color.WHITE,.6)
	if b.kind in ["hall","smith","house"]:
		var origin = p+Vector2(15,-64)
		for i in range(3):
			var a = fmod(age*.65+i*.33,1.0)
			draw_rect(Rect2(origin+Vector2(sin(age+i)*4,-a*24),Vector2(3+a*4,3+a*4)),Color(.72,.79,.74,(1-a)*.3))
	if b.kind in ["tower","hall"]:
		var flag = p+Vector2(16,-89)
		draw_line(flag,flag+Vector2(11,sin(age*5)*2),Color("e7b86e"),2)
	if b.hp < b.max_hp or b.id == selected_building:
		bar(p+Vector2(-15,8),30,float(b.hp)/b.max_hp,Color("d7ae69"))
	if b.fire > 0: draw_sprite("fire",p+Vector2(sin(age*13)*2,-20),Color(1,1,1,.9),.8)
	if b.kind == "tower" and b.id == selected_building:
		var radius = 6 if model.is_high(b) else 4
		for c in model.terrain:
			if model.distance(c,b.cell) == radius: diamond(iso(c),Color(.9,.8,.4,.7),true)

func render_unit(u: Dictionary,p: Vector2) -> void:
	var friendly: bool = u in model.units
	var frame = int(age*(8 if motions.has(u.id) else 2)+u.id)%4
	if flashes.has(u.cell): p.y -= sin(flashes[u.cell]/.25*PI)*3
	if friendly:
		draw_arc(p+Vector2(0,0),9,0,TAU,12,Color(.55,.82,.8,.6),1)
	draw_sprite(u.kind+"_"+str(frame),p)
	if model.phase == "combat" or u.id == moving_id:
		bar(p+Vector2(-9,-39),18,float(u.hp)/u.max_hp,Color("82bfab") if friendly else Color("ce765f"))
	if u.id == moving_id:
		var attack_range = int(model.udef(u.kind).range)+(2 if u.kind == "archer" and model.terrain.get(u.cell,"") == "high" else 0)
		for c in model.terrain:
			if model.distance(c,u.cell) == attack_range: diamond(iso(c),Color(.54,.79,.84,.7),true)

func bar(p: Vector2,width: float,value: float,color: Color) -> void:
	draw_rect(Rect2(p,Vector2(width,3)),Color("233b40"))
	draw_rect(Rect2(p,Vector2(width*clampf(value,0,1),2)),color)

func render_effect(fx: Dictionary) -> void:
	var t: float = fx.t/fx.life
	var p: Vector2 = fx.p
	var alpha = 1-t
	match fx.kind:
		"projectile":
			var end: Vector2 = fx.end
			var here = p.lerp(end,t)
			if fx.detail != "cannon": here.y -= sin(t*PI)*16
			var direction = (end-p).normalized()
			if fx.detail == "cannon": draw_circle(here,3,Color("f3c376"))
			else: draw_line(here-direction*7,here,Color("f0ddb4"),1)
		"gain":
			draw_string(font,p+Vector2(-9,-18-t*30),"+ "+fx.detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.95,.83,.54,alpha))
		"dust","place","collapse","boom","hit","death","fire":
			var strong = fx.kind in ["boom","collapse"]
			for i in range(10 if strong else 5):
				var angle = i*2.4
				var pos = p+Vector2(cos(angle),sin(angle)*.5)*t*(28 if strong else 14)-Vector2(0,sin(t*PI)*8)
				draw_rect(Rect2(pos,Vector2(3,3) if strong else Vector2(2,2)),Color(1,.72,.4,alpha) if strong else Color(.85,.77,.58,alpha))
		"spawn": diamond(p,Color(1,.48,.31,alpha*.5))
		"season":
			draw_colored_polygon(PackedVector2Array([Vector2(-500,-150),Vector2(500,-150),Vector2(500,500),Vector2(-500,500)]),Color(.87,.73,.42,sin(t*PI)*.12))
