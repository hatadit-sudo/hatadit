extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_rules.gd
## These tests call the actual production rules, not a reimplementation.
const Rules = preload("res://scripts/model.gd")
var failures = 0
var checks = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var m = Rules.new()
	m.save_path = "user://fjordwatch-test.save"
	m.new_game(713)
	return m

func run() -> void:
	var m = fresh()
	check(m.terrain.size() == 100,"100 board cells")
	check(m.units.size() == 3,"Initial three-person garrison")
	check(m.actions == 4,"Four initial workers")
	for b in m.buildings:
		for c in b.cells:
			check(m.inside(c),"Initial building stays in bounds")
			var count = 0
			for other in m.buildings:
				if c in other.cells: count += 1
			check(count == 1,"No initial overlapping footprints")
	for kind in m.data.buildings:
		for rotation in range(4):
			var cells = m.footprint(kind,Vector2i(3,3),rotation)
			check(cells.size() == m.bdef(kind).shape.size(),"Rotation preserves area: "+kind)
			check(m.footprint(kind,Vector2i(3,3),rotation+4) == cells,"Four rotations restore footprint")
	var old = m.snapshot().duplicate(true)
	check(m.build("house",Vector2i(9,9),0) != "","Reject boundary overflow")
	check(m.resources == old.resources and m.actions == old.actions,"Invalid placement is atomic")
	check(m.build("well",Vector2i(0,2),0) != "","Reject river placement")
	check(m.build("house",Vector2i(4,5),0) != "","Reject occupied footprint")
	check(m.build("well",Vector2i(7,4),0) != "","Reject building over soldier")
	check(m.build("smith",Vector2i(7,7),0) == "","Allow high-ground forge")
	check(m.production_preview().iron == 2,"High-ground production bonus")
	check(m.actions == 3,"Construction spends one action")
	check(m.build("warehouse",Vector2i(9,7),0) == "","Adjacent warehouse fits")
	check(m.training_cost("cannon").iron == 4,"Forge/warehouse reduces iron training cost")
	m = fresh()
	check(m.production_preview().food == 6,"River crop bonus is active")
	check(m.build("pasture",Vector2i(2,0),0) == "","Place pasture beside crop")
	check(m.production_preview().food == 11,"Pasture production and field adjacency combine")
	m.round_no = 10
	check(m.production_preview().food == 7,"Winter halves fields, not sheep")
	m = fresh()
	var id: int = m.units[0].id
	check(m.move_unit(id,Vector2i(6,4)) == "","Free deployment to open tile")
	check(m.actions == 4,"Deployment costs no workers")
	check(m.move_unit(id,Vector2i(4,5)) != "","Cannot deploy inside hall")
	m.actions = 0
	var food = m.resources.food
	check(m.action("food") != "" and m.resources.food == food,"No free actions after workers are spent")
	m = fresh()
	m.end_planning()
	check(m.round_no == 2 and m.phase == "planning","Non-invasion round advances once")
	m.end_planning()
	check(m.round_no == 3,"Round three reached")
	m.end_planning()
	check(m.phase == "preparation" and m.round_no == 3,"Invasion waits for deployment")
	var resources = m.resources.duplicate()
	m.end_planning()
	check(m.resources == resources,"Cannot collect production twice")
	m.start_combat()
	check(m.phase == "combat" and m.spawn_queue.size() == 5,"Exact first invasion composition")
	check(m.command("focus") == "" and m.commands == 1,"Command budget spent")
	m.command("retreat")
	check(m.command("charge") != "","Commands capped at two")
	# Route computation must turn around a small wall; a sealed map must return a breakable path.
	m = fresh()
	m.buildings.clear()
	m.units.clear()
	m._add_building("wall",Vector2i(6,4),1)
	var next = m.next_step(Vector2i(7,4),[Vector2i(5,4)],true,999)
	check(next != Vector2i(6,4) and next != Vector2i(7,4),"Route around wall when cheaper")
	for y in range(0,10,2): m._add_building("wall",Vector2i(5,y),1)
	next = m.next_step(Vector2i(6,2),[Vector2i(4,2)],true,999)
	check(next == Vector2i(5,2),"Sealed wall can be breached")
	m = fresh()
	var cannon = m._add_unit("cannon",Vector2i(6,3))
	var target = {"cell":Vector2i(9,4),"hp":30,"kind":"raider","id":900}
	check(not m.can_hit(cannon,target),"Cannon rejects diagonal shot")
	target.cell = Vector2i(9,3)
	check(m.can_hit(cannon,target),"Cannon accepts clear straight lane")
	var archer = m._add_unit("archer",Vector2i(7,7))
	target.cell = Vector2i(9,3)
	check(m.can_hit(archer,target),"High ground increases bow range")
	# Exact, safe save roundtrip, including active enemy positions and reload counters.
	m = fresh()
	m.round_no = 3
	m.phase = "preparation"
	m.start_combat()
	for i in range(8): m.combat_step()
	var snapshot: Dictionary = m.snapshot().duplicate(true)
	check(m.save_game(),"Save succeeds")
	var restored = fresh()
	check(restored.load_game(),"Load succeeds")
	check(restored.snapshot() == snapshot,"Save preserves exact active combat state")
	m.combat_step()
	restored.combat_step()
	check(restored.snapshot() == m.snapshot(),"Reloaded combat remains deterministic")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.erase("units")
	check(not restored.valid_snapshot(bad),"Reject incomplete save")
	bad = snapshot.duplicate(true)
	bad.version = 99
	check(not restored.valid_snapshot(bad),"Reject unknown save version")
	# Full ten-round state-machine exercise with an intentionally invulnerable test garrison.
	m = fresh()
	var count = 0
	var saw_waves: Array = []
	while m.phase not in ["victory","defeat"] and count < 4000:
		count += 1
		for b in m.buildings: b.hp = 100000
		for u in m.units: u.hp = 100000
		m.resources.food = 1000
		match m.phase:
			"planning": m.end_planning()
			"preparation": saw_waves.append(m.round_no); m.start_combat()
			"combat":
				m.combat_step()
				# Clean up live attackers only after actual spawn, so wave/aftermath logic runs.
				for e in m.enemies: e.hp = 0
			"aftermath": m.finish_round()
	check(m.phase == "victory","Session can reach victory")
	check(saw_waves == [3,5,8,10],"All four invasions occur in order")
	check(m.score > 0,"Victory produces a score")
	m = fresh()
	m.get_hall().hp = 0
	m.finish_round()
	check(m.phase == "defeat","Hall loss ends the session")
	# Never leave test saves in the normal game profile.
	DirAccess.remove_absolute("user://fjordwatch-test.save")
	print("RULE CHECKS: %d; FAILURES: %d" % [checks,failures])
	quit(1 if failures > 0 else 0)
