extends SceneTree
## Native integration test. Use Xvfb for real render captures; headless for logic only.
## godot --path . --script res://tests/test_scene.gd -- --capture
var game
var failures = 0
var checks = 0
const TEST_SAVE = "user://fjordwatch-scene-test.save"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func capture(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	check(frame != null and not frame.is_empty(),"Rendered frame is available")
	if frame != null and not frame.is_empty():
		check(frame.save_png("res://build/"+filename) == OK,"Save native screenshot: "+filename)

func run() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.make_dir_recursive_absolute("res://build")
	var scene: PackedScene = load("res://main.tscn")
	check(scene != null,"Main scene imports")
	if scene == null:
		quit(1)
		return
	game = scene.instantiate()
	game.model.save_path = TEST_SAVE
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.model.phase == "planning","Scene boots into planning")
	check(game.dock.get_child_count() == 8,"Worker action toolbar populated")
	check(game.world.sprites.size() >= 75,"World loads its real sprites")
	check(game.root.size.x >= 1200 and game.root.size.y >= 700,"Logical landscape viewport")
	await capture("scene_start.png")
	game.change_tab("build")
	check(game.dock.get_child_count() == 9,"Nine build buttons populated")
	game.select_build("smith")
	game.pick(Vector2i(7,7))
	var before: int = game.model.buildings.size()
	game.confirm_placement()
	check(game.model.buildings.size() == before+1,"UI placement creates a real building")
	check(game.model.actions == 3,"UI placement spends a worker exactly once")
	check(game.world.selection == "","Placement clears ghost")
	var shield = game.model.units[0]
	game.pick(shield.cell)
	game.pick(Vector2i(6,4))
	check(shield.cell == Vector2i(6,4),"UI troop redeployment")
	var original_position: Vector2 = game.world.position
	game.feedback("boom",Vector2i(4,4),"")
	game._process(.04)
	game._process(.25)
	check(game.world.position == original_position,"Cannon shake does not drift camera")
	game.show_menu()
	check(game.modal != null,"Menu opens")
	game.close_modal()
	check(game.modal == null,"Menu closes")
	game.model.round_no = 3
	game.advance()
	check(game.model.phase == "preparation","End round enters deployment")
	game.advance()
	game.paused = true
	for i in range(10): game.model.combat_step()
	check(game.model.phase == "combat","Live battle progresses")
	check(game.model.enemies.size() > 0,"Enemy sprites have model entities")
	await process_frame
	await capture("scene_battle.png")
	check(game.autosave(),"Scene autosave succeeds")
	var saved: Dictionary = game.model.snapshot().duplicate(true)
	game.model.resources.wood += 50
	check(game.model.load_game(),"Scene save loads")
	check(game.model.snapshot() == saved,"Scene state restores exactly")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_SAVE)
	print("SCENE CHECKS: %d; FAILURES: %d" % [checks,failures])
	quit(1 if failures > 0 else 0)
