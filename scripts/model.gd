extends RefCounted
## Deterministic game rules. No rendering or frame-rate dependent combat.
signal changed
signal feedback(kind: String, cell: Vector2i, detail: String)
const SIZE = 10
const DIRS = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
const SAVE_PATH = "user://fjordwatch.save"
var save_path: String = SAVE_PATH
var data: Dictionary = {}
var terrain: Dictionary = {}
var buildings: Array = []
var units: Array = []
var enemies: Array = []
var resources: Dictionary = {}
var round_no: int = 1
var actions: int = 4
var population: int = 4
var morale: int = 6
var tools_level: int = 0
var phase: String = "planning"
var tick: int = 0
var commands: int = 2
var focus_ticks: int = 0
var charge_ticks: int = 0
var next_id: int = 1
var kills: int = 0
var lost_buildings: int = 0
var score: int = 0
var seed_value: int = 713
var leader: String = "Steward"
var objective: String = "Harvest"
var event_text: String = ""
var report: String = ""
var spawn_queue: Array = []
var pending_side: String = "east"
var rng = RandomNumberGenerator.new()

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data.json"))

func new_game(game_seed: int = 713) -> void:
	seed_value = game_seed
	rng.seed = game_seed
	terrain.clear()
	buildings.clear()
	units.clear()
	enemies.clear()
	spawn_queue.clear()
	report = ""
	pending_side = "east"
	next_id = 1
	round_no = 1
	population = 4
	morale = 6
	tools_level = 0
	kills = 0
	lost_buildings = 0
	score = 0
	phase = "planning"
	tick = 0
	commands = 2
	focus_ticks = 0
	charge_ticks = 0
	leader = ["Steward", "Warden", "Trader"][posmod(game_seed,3)]
	objective = ["Harvest", "Fortress", "Community"][posmod(game_seed / 3,3)]
	resources = {"food":20,"wood":20,"stone":10,"iron":9,"silver":5}
	if leader == "Steward": resources.food += 4
	if leader == "Warden": resources.iron += 2
	if leader == "Trader": resources.silver += 4
	for y in range(SIZE):
		for x in range(SIZE):
			var c = Vector2i(x,y)
			terrain[c] = "grass"
			if x == 0 and y != 4: terrain[c] = "river"
			if (x >= 6 and y >= 6) or (x == 7 and y == 5): terrain[c] = "high"
			if y == 4 or x == 5: terrain[c] = "road"
	_add_building("hall", Vector2i(4,5),0)
	_add_building("house", Vector2i(2,6),0)
	_add_building("farm", Vector2i(1,2),0)
	_add_building("lumber", Vector2i(1,8),0)
	_add_building("well", Vector2i(2,5),0)
	_add_unit("shield",Vector2i(7,4))
	_add_unit("shield",Vector2i(5,3))
	_add_unit("archer",Vector2i(6,6))
	begin_round()

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE

func bdef(kind: String) -> Dictionary:
	return data.buildings[kind]

func udef(kind: String) -> Dictionary:
	return data.units[kind]

func footprint(kind: String, at: Vector2i, rotation: int) -> Array:
	var points: Array = []
	var min_x: int = 100
	var min_y: int = 100
	for pair in bdef(kind).shape:
		var v = Vector2i(int(pair[0]),int(pair[1]))
		for i in range(posmod(rotation,4)): v = Vector2i(-v.y,v.x)
		points.append(v)
		min_x = mini(min_x,v.x)
		min_y = mini(min_y,v.y)
	var result: Array = []
	for p in points: result.append(at + p - Vector2i(min_x,min_y))
	return result

func building_at(c: Vector2i) -> Dictionary:
	for b in buildings:
		if b.hp > 0 and c in b.cells: return b
	return {}

func unit_at(c: Vector2i, list: Array) -> Dictionary:
	for u in list:
		if u.hp > 0 and u.cell == c: return u
	return {}

func neighbors(b: Dictionary, kind: String) -> bool:
	for c in b.cells:
		for d in DIRS:
			var other = building_at(c+d)
			if not other.is_empty() and other.id != b.id and other.kind == kind: return true
	return false

func beside_terrain(b: Dictionary, kind: String) -> bool:
	for c in b.cells:
		for d in DIRS:
			if terrain.get(c+d,"") == kind: return true
	return false

func is_high(b: Dictionary) -> bool:
	for c in b.cells:
		if terrain.get(c,"") == "high": return true
	return false

func woodland(b: Dictionary) -> bool:
	for c in b.cells:
		if c.x <= 2 or c.y == 9: return true
	return false

func can_pay(cost: Dictionary) -> bool:
	for k in cost:
		if resources.get(k,0) < cost[k]: return false
	return true

func pay(cost: Dictionary) -> void:
	for k in cost: resources[k] -= int(cost[k])

func placement_error(kind: String, at: Vector2i, rotation: int) -> String:
	if phase != "planning": return "Build during the planning phase."
	if actions < 1: return "No workers left. End this round."
	if not can_pay(bdef(kind).cost): return "Not enough resources."
	for c in footprint(kind,at,rotation):
		if not inside(c): return "Keep the whole footprint inside the estate."
		if terrain[c] == "river": return "Cannot build on water."
		if not building_at(c).is_empty(): return "That footprint overlaps a building."
		if not unit_at(c,units).is_empty(): return "Move the soldier first."
	return ""

func _add_building(kind: String, at: Vector2i, rotation: int) -> Dictionary:
	var spec = bdef(kind)
	var b = {"id":next_id,"kind":kind,"cell":at,"rotation":rotation,"cells":footprint(kind,at,rotation),"hp":int(spec.hp),"max_hp":int(spec.hp),"fire":0,"cooldown":0}
	next_id += 1
	buildings.append(b)
	if kind == "wall" and neighbors(b,"wall"):
		b.max_hp += 10
		b.hp += 10
	return b

func build(kind: String, at: Vector2i, rotation: int) -> String:
	var error = placement_error(kind,at,rotation)
	if error != "": return error
	pay(bdef(kind).cost)
	actions -= 1
	_add_building(kind,at,rotation)
	if kind == "house": population += 1
	feedback.emit("place",at,kind)
	changed.emit()
	return ""

func _add_unit(kind: String, at: Vector2i) -> Dictionary:
	var spec = udef(kind)
	var u = {"id":next_id,"kind":kind,"cell":at,"home":at,"hp":int(spec.hp),"max_hp":int(spec.hp),"cooldown":0,"steps":0,"last_dir":Vector2i.ZERO,"slow":0}
	next_id += 1
	units.append(u)
	return u

func training_cost(kind: String) -> Dictionary:
	var cost: Dictionary = udef(kind).cost.duplicate()
	for b in buildings:
		if b.kind == "smith" and b.hp > 0 and neighbors(b,"warehouse"):
			cost.iron = maxi(0,int(cost.iron)-1)
			break
	return cost

func train(kind: String, at: Vector2i) -> String:
	if phase != "planning" or actions < 1: return "Training needs one available worker."
	if units.size() >= population + 2: return "Build a longhouse for a larger garrison."
	if not walkable(at) or not unit_at(at,units).is_empty(): return "Choose a free, passable tile."
	var cost = training_cost(kind)
	if not can_pay(cost): return "Not enough resources for training."
	pay(cost)
	actions -= 1
	_add_unit(kind,at)
	feedback.emit("place",at,kind)
	changed.emit()
	return ""

func move_unit(id: int, at: Vector2i) -> String:
	if phase != "planning" and phase != "preparation": return "Reposition before combat."
	if not walkable(at) or not unit_at(at,units).is_empty(): return "Choose an empty, passable tile."
	for u in units:
		if u.id == id:
			u.cell = at
			u.home = at
			feedback.emit("place",at,u.kind)
			changed.emit()
			return ""
	return "Soldier no longer available."

func action(name: String) -> String:
	if phase != "planning" or actions <= 0: return "No available workers."
	var at = Vector2i(4,5)
	match name:
		"wood": resources.wood += 4; at = Vector2i(1,8)
		"stone": resources.stone += 3; at = Vector2i(8,8)
		"iron": resources.iron += 2; at = Vector2i(8,7)
		"food": resources.food += 5; at = Vector2i(2,2)
		"tools":
			if tools_level >= 3: return "Tools are fully improved."
			if resources.iron < 3 or resources.wood < 2: return "Tools need 3 iron and 2 wood."
			resources.iron -= 3
			resources.wood -= 2
			tools_level += 1
		"trade":
			if resources.silver < 2: return "Trade needs 2 silver."
			resources.silver -= 2
			resources.food += 6 + (2 if has_building("warehouse") else 0) + (2 if leader == "Trader" else 0)
			resources.wood += 2
		"repair":
			if resources.wood < 3: return "Repairs need 3 wood."
			resources.wood -= 3
			for b in buildings: b.hp = mini(b.max_hp,b.hp+25); b.fire = 0
			for u in units: u.hp = mini(u.max_hp,u.hp+15)
		"explore":
			if resources.food < 3: return "Exploration needs 3 food."
			resources.food -= 3
			resources.silver += 3
			resources.iron += 1
		_: return "Unknown action."
	actions -= 1
	feedback.emit("gain",at,name)
	changed.emit()
	return ""

func demolish(id: int) -> String:
	if phase != "planning" or actions < 1: return "Dismantling needs a worker."
	for b in buildings:
		if b.id != id: continue
		if b.kind == "hall": return "The hearth cannot be dismantled."
		for k in bdef(b.kind).cost: resources[k] += int(bdef(b.kind).cost[k] / 2)
		if b.kind == "house": population = maxi(1,population-1)
		buildings.erase(b)
		actions -= 1
		changed.emit()
		return ""
	return "Building not found."

func has_building(kind: String) -> bool:
	for b in buildings:
		if b.kind == kind and b.hp > 0: return true
	return false

func season() -> String:
	return ["SPRING","SUMMER","AUTUMN","WINTER"][mini(3,(round_no-1)/3)]

func begin_round() -> void:
	phase = "planning"
	actions = mini(6,population)
	if morale <= 2: actions = maxi(2,actions-1)
	var events = ["Thaw: the eastern ford is open.","Woodcutters return: +2 wood.","Raiders sighted. Deploy at the eastern approach.","Traveling merchants: +2 silver.","War horns in the north. A sapper is among them.","A mild summer: +3 food.","Harvest festival: +1 morale.","Smoke to the east. Protect wooden buildings.","Winter is near. Store food and repair the hearth.","Last stand. Attacks from NORTH and EAST."]
	event_text = events[round_no-1]
	match round_no:
		2: resources.wood += 2
		4: resources.silver += 2
		6: resources.food += 3
		7: morale = mini(10,morale+1)
	changed.emit()

func production_preview() -> Dictionary:
	var gain = {"food":0,"wood":0,"stone":0,"iron":0,"silver":1}
	for b in buildings:
		if b.hp <= 0: continue
		match b.kind:
			"farm":
				var n = 4 + tools_level
				if beside_terrain(b,"river"): n += 2
				if neighbors(b,"pasture"): n += 2
				gain.food += maxi(1,n/2) if season() == "WINTER" else n
			"pasture": gain.food += 3
			"lumber": gain.wood += 3 + tools_level + (2 if woodland(b) else 0)
			"smith": gain.iron += 1 + (1 if is_high(b) else 0)
			"warehouse": gain.silver += 1
			"house":
				if neighbors(b,"house"): gain.food += 1
	return gain

func upkeep() -> int:
	return population + int(ceil(units.size()/2.0)) + (2 if season() == "WINTER" else 0)

func end_planning() -> void:
	if phase != "planning": return
	var gain = production_preview()
	for k in gain: resources[k] += gain[k]
	var mood = 0
	for b in buildings:
		if b.kind == "house":
			if neighbors(b,"well"): mood += 1
			if neighbors(b,"smith"): mood -= 1
		if b.kind == "well" and neighbors(b,"pasture"): mood -= 2
	morale = clampi(morale+mood,0,10)
	report = "Produced: %d food, %d timber, %d iron, %d silver. Upkeep: %d food." % [gain.food,gain.wood,gain.iron,gain.silver,upkeep()]
	feedback.emit("round",Vector2i(4,5),report)
	if data.waves.has(str(round_no)):
		phase = "preparation"
		pending_side = data.waves[str(round_no)].side
		changed.emit()
	else: finish_round()

func finish_round() -> void:
	resources.food -= upkeep()
	if resources.food < 0:
		morale = maxi(0,morale-2)
		population = maxi(1,population-1)
		var hall = get_hall()
		if not hall.is_empty(): hall.hp = maxi(0,hall.hp-12)
		resources.food = 0
		report += " Hunger: -1 resident, -2 morale, -12 hearth health."
	for u in units:
		u.hp = mini(u.max_hp,u.hp+7)
		u.cell = u.home
		u.cooldown = 0
		u.steps = 0
	for b in buildings: b.fire = 0
	if get_hall().is_empty() or get_hall().hp <= 0:
		finish_game(false)
		return
	if round_no >= 10:
		finish_game(true)
		return
	round_no += 1
	begin_round()
	save_game()

func get_hall() -> Dictionary:
	for b in buildings:
		if b.kind == "hall": return b
	return {}

func start_combat() -> void:
	if phase != "preparation": return
	save_game()
	phase = "combat"
	tick = 0
	commands = 2
	focus_ticks = 0
	charge_ticks = 0
	enemies.clear()
	spawn_queue = data.waves[str(round_no)].units.duplicate()
	for u in units: u.cooldown = 0
	changed.emit()

func walkable(c: Vector2i) -> bool:
	if not inside(c) or terrain.get(c,"") == "river": return false
	var b = building_at(c)
	return b.is_empty() or not bdef(b.kind).block

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func building_distance(c: Vector2i,b: Dictionary) -> int:
	var best = 999
	for cell in b.cells: best = mini(best,distance(c,cell))
	return best

func clear_shot(a: Vector2i,b: Vector2i, elevated: bool = false) -> bool:
	var delta = Vector2(b-a)
	var steps = maxi(absi(b.x-a.x),absi(b.y-a.y))
	for i in range(1,steps):
		var c = Vector2i((Vector2(a)+delta*float(i)/steps).round())
		var obstacle = building_at(c)
		if not obstacle.is_empty() and bdef(obstacle.kind).block:
			if not elevated or obstacle.kind == "wall": return false
	return true

func can_hit(u: Dictionary, target: Dictionary) -> bool:
	var spec = udef(u.kind)
	var attack_range: int = int(spec.range)
	var elevated = terrain.get(u.cell,"") == "high"
	if u.kind in ["archer","enemy_archer"] and elevated: attack_range += 2
	if distance(u.cell,target.cell) > attack_range: return false
	if u.kind in ["spear","cannon"] and u.cell.x != target.cell.x and u.cell.y != target.cell.y: return false
	return clear_shot(u.cell,target.cell,elevated) if attack_range > 1 else true

func target_for(u: Dictionary, targets: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_rank = -99999.0
	for target in targets:
		if target.hp <= 0 or not can_hit(u,target): continue
		var rank = -float(distance(u.cell,target.cell))*4.0
		if u.kind == "archer" and target.kind in ["enemy_archer","firebrand","sapper"]: rank += 14
		if u.kind == "cannon":
			for other in targets:
				if other.hp > 0 and distance(target.cell,other.cell) <= 1: rank += 10
		if rank > best_rank:
			best = target
			best_rank = rank
	return best

func strike(u: Dictionary,target: Dictionary,friendly: bool) -> void:
	var spec = udef(u.kind)
	var damage: int = int(spec.damage)
	if friendly and leader == "Warden": damage += 1
	if friendly and focus_ticks > 0 and spec.range > 2: damage += 4
	if u.kind == "cavalry" and (u.steps >= 3 or charge_ticks > 0): damage *= 2
	var armor: int = int(udef(target.kind).armor)
	if u.kind == "cannon": armor = 0
	target.hp -= maxi(1,damage-armor)
	u.cooldown = int(spec.reload)
	u.steps = 0
	feedback.emit("projectile" if spec.range > 2 else "hit",u.cell,"%d,%d,%s" % [target.cell.x,target.cell.y,u.kind])
	if u.kind == "cannon":
		for other in enemies:
			if other.id != target.id and other.hp > 0 and distance(target.cell,other.cell) <= 1: other.hp -= int(damage/2)
		feedback.emit("boom",target.cell,"")

func enemy_goal(e: Dictionary) -> Dictionary:
	var desired = "hall"
	if e.kind == "raider" and has_building("warehouse"): desired = "warehouse"
	if e.kind == "sapper" and has_building("wall"): desired = "wall"
	var best: Dictionary = {}
	var best_dist = 999
	for b in buildings:
		if b.hp <= 0 or b.kind != desired: continue
		var d = building_distance(e.cell,b)
		if d < best_dist: best = b; best_dist = d
	return best

func next_step(start: Vector2i, goals: Array, hostile: bool, mover_id: int) -> Vector2i:
	# Weighted Dijkstra: walls are costly, destructible routes, never magical dead ends.
	var frontier: Array = [start]
	var cost: Dictionary = {start:0.0}
	var came: Dictionary = {}
	var finish = start
	while not frontier.is_empty():
		var best_index = 0
		for i in range(1,frontier.size()):
			if cost[frontier[i]] < cost[frontier[best_index]]: best_index = i
		var current: Vector2i = frontier.pop_at(best_index)
		if current in goals:
			finish = current
			break
		for dir in DIRS:
			var c: Vector2i = current+dir
			if not inside(c) or terrain[c] == "river": continue
			var step_cost = 1.0
			var obstacle = building_at(c)
			if not obstacle.is_empty():
				if bdef(obstacle.kind).block:
					if not hostile: continue
					step_cost += float(obstacle.hp)/8.0
				elif obstacle.kind == "farm": step_cost += 1.2
			var occupied = unit_at(c,enemies if hostile else units)
			if not occupied.is_empty() and occupied.id != mover_id: continue
			var rival = unit_at(c,units if hostile else enemies)
			if not rival.is_empty():
				if hostile: step_cost += float(rival.hp)/8.0
				else: continue
			var total = float(cost[current])+step_cost
			if not cost.has(c) or total < cost[c]:
				cost[c] = total
				came[c] = current
				if c not in frontier: frontier.append(c)
	if finish == start: return start
	while came.has(finish) and came[finish] != start: finish = came[finish]
	return finish

func move_combat(u: Dictionary, cell: Vector2i) -> void:
	if cell == u.cell: return
	var direction: Vector2i = cell-u.cell
	u.steps = u.steps+1 if direction == u.last_dir else 1
	u.last_dir = direction
	var old: Vector2i = u.cell
	u.cell = cell
	var ground = building_at(cell)
	if not ground.is_empty() and ground.kind == "farm": u.slow = 1
	feedback.emit("move",old,"%d,%d,%d" % [u.id,cell.x,cell.y])

func damage_building(e: Dictionary,b: Dictionary) -> void:
	var damage: int = int(udef(e.kind).damage)
	if e.kind == "sapper" and b.kind == "wall": damage *= 2
	b.hp -= damage
	e.cooldown = int(udef(e.kind).reload)
	if e.kind == "firebrand" and bdef(b.kind).wooden and not neighbors(b,"well"): b.fire = 7
	if e.kind == "raider" and b.kind == "warehouse": resources.silver = maxi(0,resources.silver-1)
	feedback.emit("hit",b.cell,"")

func spawn_enemy() -> void:
	if spawn_queue.is_empty(): return
	var north = pending_side == "north" or (pending_side == "both" and tick%4 < 2)
	for i in range(10):
		var lane = posmod(tick+i,10)
		var cell = Vector2i(lane,0) if north else Vector2i(9,lane)
		if terrain.get(cell, "") == "river": continue
		if not unit_at(cell,enemies).is_empty() or not unit_at(cell,units).is_empty(): continue
		var kind: String = spawn_queue.pop_front()
		var spec = udef(kind)
		var e = {"id":next_id,"kind":kind,"cell":cell,"home":cell,"hp":int(spec.hp),"max_hp":int(spec.hp),"cooldown":0,"steps":0,"last_dir":Vector2i.ZERO,"slow":0}
		next_id += 1
		enemies.append(e)
		feedback.emit("spawn",cell,kind)
		return

func combat_step() -> void:
	if phase != "combat": return
	tick += 1
	focus_ticks = maxi(0,focus_ticks-1)
	charge_ticks = maxi(0,charge_ticks-1)
	if tick%2 == 1: spawn_enemy()
	for u in units:
		if u.hp <= 0: continue
		u.cooldown = maxi(0,u.cooldown-1)
		if u.cooldown > 0: continue
		var target = target_for(u,enemies)
		if not target.is_empty(): strike(u,target,true)
		elif u.kind == "cavalry" and not enemies.is_empty():
			var goals: Array = []
			for e in enemies:
				if e.hp <= 0: continue
				for d in DIRS:
					if walkable(e.cell+d): goals.append(e.cell+d)
			move_combat(u,next_step(u.cell,goals,false,u.id))
	for b in buildings:
		if b.hp <= 0: continue
		if b.kind == "tower":
			b.cooldown = maxi(0,b.cooldown-1)
			if b.cooldown == 0:
				for e in enemies:
					if e.hp > 0 and distance(b.cell,e.cell) <= (6 if is_high(b) else 4) and clear_shot(b.cell,e.cell,is_high(b)):
						e.hp -= maxi(2,10-int(udef(e.kind).armor))
						b.cooldown = 3
						feedback.emit("projectile",b.cell,"%d,%d,archer" % [e.cell.x,e.cell.y])
						break
	for e in enemies:
		if e.hp <= 0: continue
		e.cooldown = maxi(0,e.cooldown-1)
		if e.cooldown > 0: continue
		var target = target_for(e,units)
		if not target.is_empty():
			strike(e,target,false)
			continue
		var goal = enemy_goal(e)
		if goal.is_empty(): continue
		var under = building_at(e.cell)
		if not under.is_empty() and bdef(under.kind).block:
			damage_building(e,under)
			continue
		if building_distance(e.cell,goal) <= 1:
			damage_building(e,goal)
			continue
		if tick%int(udef(e.kind).speed) != 0: continue
		if e.slow > 0: e.slow -= 1; continue
		var next = next_step(e.cell,goal.cells,true,e.id)
		var guard = unit_at(next,units)
		var obstacle = building_at(next)
		if not guard.is_empty(): strike(e,guard,false)
		elif not obstacle.is_empty() and bdef(obstacle.kind).block: damage_building(e,obstacle)
		else: move_combat(e,next)
	if tick%3 == 0:
		var ignite: Array = []
		for b in buildings:
			if b.hp <= 0 or b.fire <= 0: continue
			b.hp -= 4
			b.fire -= 1
			feedback.emit("fire",b.cell,"")
			if tick%9 == 0:
				for c in b.cells:
					for dir in DIRS:
						var n = building_at(c+dir)
						if not n.is_empty() and n.id != b.id and bdef(n.kind).wooden and not neighbors(n,"well"): ignite.append(n)
		for b in ignite: b.fire = maxi(b.fire,3)
	var survivors: Array = []
	for e in enemies:
		if e.hp <= 0:
			kills += 1
			feedback.emit("death",e.cell,e.kind)
		else: survivors.append(e)
	enemies = survivors
	units = units.filter(func(u): return u.hp > 0)
	var hall_dead = false
	var standing: Array = []
	for b in buildings:
		if b.hp <= 0:
			if b.kind == "hall": hall_dead = true
			if b.kind == "house": population = maxi(1,population-1)
			lost_buildings += 1
			feedback.emit("collapse",b.cell,b.kind)
		else: standing.append(b)
	buildings = standing
	if hall_dead:
		finish_game(false)
		return
	if enemies.is_empty() and spawn_queue.is_empty():
		resources.silver += 3
		report += " Invasion repelled. +3 silver."
		phase = "aftermath"
		changed.emit()
		return
	# No silent endless battle: a besieged settlement loses after five simulated minutes.
	if tick >= 600: finish_game(false)
	changed.emit()

func command(name: String) -> String:
	if phase != "combat" or commands <= 0: return "No commands remaining."
	match name:
		"focus": focus_ticks = 12
		"charge": charge_ticks = 10
		"retreat":
			for u in units:
				var goals: Array = []
				var hall = get_hall()
				if hall.is_empty(): continue
				for c in hall.cells:
					for d in DIRS:
						if walkable(c+d): goals.append(c+d)
				var cell = next_step(u.cell,goals,false,u.id)
				if unit_at(cell,enemies).is_empty(): move_combat(u,cell)
		_: return "Unknown command."
	commands -= 1
	changed.emit()
	return ""

func objective_bonus() -> int:
	if objective == "Harvest": return 40 if resources.food >= 25 else 0
	if objective == "Community": return 40 if population >= 7 and morale >= 7 else 0
	var defenses = 0
	for b in buildings:
		if b.kind in ["tower","wall"]: defenses += 1
	return 40 if defenses >= 4 else 0

func finish_game(won: bool) -> void:
	phase = "victory" if won else "defeat"
	score = maxi(0,population*15+buildings.size()*8+resources.food+units.size()*10+kills*2+objective_bonus()-lost_buildings*12+(100 if won else 0))
	changed.emit()
	save_game()

func snapshot() -> Dictionary:
	return {"version":1,"terrain":terrain,"buildings":buildings,"units":units,"enemies":enemies,"resources":resources,"round_no":round_no,"actions":actions,"population":population,"morale":morale,"tools_level":tools_level,"phase":phase,"tick":tick,"commands":commands,"focus_ticks":focus_ticks,"charge_ticks":charge_ticks,"next_id":next_id,"kills":kills,"lost_buildings":lost_buildings,"score":score,"seed_value":seed_value,"leader":leader,"objective":objective,"event_text":event_text,"report":report,"spawn_queue":spawn_queue,"pending_side":pending_side}

func save_game() -> bool:
	var file = FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_var(snapshot())
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(save_path+".tmp",save_path) == OK

func load_game() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var file = FileAccess.open(save_path,FileAccess.READ)
	if file == null: return false
	var s = file.get_var(false)
	if not valid_snapshot(s): return false
	for key in snapshot():
		if key != "version": set(key,s[key])
	changed.emit()
	return true

func valid_snapshot(s: Variant) -> bool:
	if not s is Dictionary or s.get("version",0) != 1: return false
	for key in snapshot():
		if not s.has(key) or typeof(s[key]) != typeof(snapshot()[key]): return false
	if s.round_no < 1 or s.round_no > 10: return false
	if s.phase not in ["planning","preparation","combat","aftermath","victory","defeat"]: return false
	for key in ["food","wood","stone","iron","silver"]:
		if not s.resources.has(key) or not s.resources[key] is int: return false
	if s.terrain.size() != SIZE*SIZE: return false
	for b in s.buildings:
		if not b is Dictionary: return false
		for key in ["id","kind","cell","rotation","cells","hp","max_hp","fire","cooldown"]:
			if not b.has(key): return false
		if not data.buildings.has(b.kind) or not b.cell is Vector2i: return false
	for u in s.units+s.enemies:
		if not u is Dictionary: return false
		for key in ["id","kind","cell","home","hp","max_hp","cooldown","steps","last_dir","slow"]:
			if not u.has(key): return false
		if not data.units.has(u.kind) or not u.cell is Vector2i: return false
	return true
