extends SceneTree
const Rules = preload("res://scripts/model.gd")
var results: Array = []
func _initialize() -> void:
	call_deferred("run")

func ensure(m, kind: String, at: Vector2i) -> bool:
	var b = m.building_at(at)
	if not b.is_empty(): return false
	return m.build(kind,at,0) == ""

func recruit(m,kind: String) -> bool:
	var cells = [Vector2i(8,6),Vector2i(9,6),Vector2i(6,7),Vector2i(9,8),Vector2i(7,8),Vector2i(4,3),Vector2i(6,3)]
	if kind == "cannon": cells.push_front(Vector2i(6,4))
	for c in cells:
		if m.train(kind,c) == "": return true
	return false

func plan(m,variant: int) -> void:
	var guard = 0
	while m.actions > 0 and guard < 20:
		guard += 1
		if m.resources.food < m.upkeep() and m.action("food") == "": continue
		if ensure(m,"farm",Vector2i(1,0)): continue
		if ensure(m,"smith",Vector2i(7,7)): continue
		if ensure(m,"tower",Vector2i(7,5)): continue
		if ensure(m,"house",Vector2i(3,7)): continue
		if ensure(m,"tower",Vector2i(6,2)): continue
		if ensure(m,"tower",Vector2i(8,8)): continue
		if ensure(m,"farm",Vector2i(1,3)): continue
		if ensure(m,"tower",Vector2i(3,4)): continue
		if not m.get_hall().is_empty() and m.get_hall().hp < 110:
			if m.action("repair") == "": continue
		var cannon_count = 0
		for u in m.units:
			if u.kind == "cannon": cannon_count += 1
		if variant > 0 and cannon_count == 0 and recruit(m,"cannon"): continue
		if recruit(m,"archer"): continue
		if m.resources.stone < 4: m.action("stone")
		elif m.resources.wood < 9: m.action("wood")
		elif m.resources.iron < 5: m.action("iron")
		elif m.resources.food < 25: m.action("food")
		elif m.action("repair") != "": m.action("wood")

func simulate(seed_number: int,variant: int) -> Dictionary:
	var m = Rules.new()
	m.save_path = "user://fjordwatch-playtest.save"
	m.new_game(seed_number)
	var steps = 0
	var history: Array = []
	while m.phase not in ["victory","defeat"] and steps < 3000:
		steps += 1
		match m.phase:
			"planning":
				plan(m,variant)
				history.append({"round":m.round_no,"people":m.population,"army":m.units.size(),"buildings":m.buildings.size(),"food":m.resources.food})
				m.end_planning()
			"preparation": m.start_combat()
			"combat":
				if m.tick == 4: m.command("focus")
				if m.tick == 18: m.command("focus")
				m.combat_step()
			"aftermath": m.finish_round()
	var outcome = {"seed":seed_number,"variant":variant,"phase":m.phase,"round":m.round_no,"score":m.score,"kills":m.kills,"history":history}
	return outcome

func run() -> void:
	for seed_number in [711,712,713]:
		for variant in [0,1]: results.append(simulate(seed_number,variant))
	DirAccess.remove_absolute("user://fjordwatch-playtest.save")
	var file = FileAccess.open("res://build/playthrough.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	var wins = 0
	for r in results:
		if r.phase == "victory": wins += 1
		print("PLAYTEST seed=%d variant=%d result=%s round=%d score=%d kills=%d" % [r.seed,r.variant,r.phase,r.round,r.score,r.kills])
	print("LEGAL PLAYTHROUGH VICTORIES: %d / %d" % [wins,results.size()])
	quit(0 if wins > 0 else 1)
