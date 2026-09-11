extends Node2D
const Rules = preload("res://scripts/model.gd")
const World = preload("res://scripts/world.gd")
var model = Rules.new()
var world = World.new()
var ui = CanvasLayer.new()
var root = Control.new()
var top = HBoxContainer.new()
var dock = HBoxContainer.new()
var info = Label.new()
var hint = Label.new()
var toast = Label.new()
var resource_labels: Dictionary = {}
var round_label: Label
var worker_label: Label
var end_button: Button
var context = HBoxContainer.new()
var modal: Control
var tab = "work"
var timer: float = 0.0
var speed: float = 1.0
var paused: bool = false
var selected_cell = Vector2i(-100,-100)
var drag_start = Vector2.ZERO
var drag_last = Vector2.ZERO
var dragging: bool = false
var panning: bool = false
var touches: Dictionary = {}
var pinching: bool = false
var pinch_cooldown: float = 0.0
var toast_time: float = 0.0
var audio_players: Array = []
var audio_index: int = 0
var muted: bool = false
var sounds: Dictionary = {}
var current_phase: String = ""
var flyouts: Array = []
var transition: ColorRect
var session_seed: int = 713
var base_world_position = Vector2(640,169)
var shake: float = 0.0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	world.position = base_world_position
	world.scale = Vector2(1.35,1.35)
	add_child(world)
	world.setup(model)
	build_ui()
	for kind in ["click","place","gain","shot","boom","round","hit"]:
		sounds[kind] = load("res://assets/"+kind+".wav")
	for i in range(8):
		var player = AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)
	model.changed.connect(refresh)
	model.feedback.connect(feedback)
	model.new_game(session_seed)
	if FileAccess.file_exists(model.save_path):
		if model.load_game(): notify("Welcome back. Your settlement has been restored.")
		else: notify("Previous save could not be loaded. A new settlement is ready.")
	else:
		notify("Welcome, Jarl. Tap a worker action, or BUILD to shape the estate. HELP explains the board.")
	refresh()

func panel_style(background: Color, edge: Color = Color("587271")) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = background
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func label(text: String, size: int = 16, color: Color = Color("e9dfc5")) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(text: String, callback: Callable, width: float = 84, gold: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width,44)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",15)
	b.add_theme_color_override("font_color",Color("eadfc3"))
	b.add_theme_stylebox_override("normal",panel_style(Color("6b5738") if gold else Color("233e43"),Color("b59658") if gold else Color("58716d")))
	b.add_theme_stylebox_override("hover",panel_style(Color("405951"),Color("c8b785")))
	b.add_theme_stylebox_override("pressed",panel_style(Color("182e35"),Color("edca7b")))
	b.add_theme_stylebox_override("disabled",panel_style(Color("253538"),Color("364c4e")))
	b.add_theme_color_override("font_disabled_color",Color("75817b"))
	b.pressed.connect(func():
		play_sound("click")
		callback.call()
	)
	b.button_down.connect(func():
		b.pivot_offset = b.size*.5
		var tw = b.create_tween()
		tw.tween_property(b,"scale",Vector2(.96,.96),.08)
	)
	b.button_up.connect(func():
		var tw = b.create_tween()
		tw.tween_property(b,"scale",Vector2.ONE,.12).set_trans(Tween.TRANS_BACK)
	)
	return b

func build_ui() -> void:
	add_child(ui)
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font_size = 16
	root.theme = theme
	var header = Panel.new()
	header.position = Vector2(0,0)
	header.size = Vector2(1280,56)
	header.add_theme_stylebox_override("panel",panel_style(Color("162f37")))
	root.add_child(header)
	top.position = Vector2(18,5)
	top.size = Vector2(1244,46)
	top.add_theme_constant_override("separation",14)
	root.add_child(top)
	round_label = label("",18)
	round_label.custom_minimum_size.x = 197
	top.add_child(round_label)
	for k in ["food","wood","stone","iron","silver"]:
		var row = HBoxContainer.new()
		var icon = TextureRect.new()
		icon.texture = load("res://assets/res_"+k+".png")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(26,26)
		row.add_child(icon)
		var amount = label("0",18)
		amount.custom_minimum_size.x = 44
		row.add_child(amount)
		top.add_child(row)
		resource_labels[k] = amount
	worker_label = label("",16,Color("bdd4bf"))
	worker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(worker_label)
	top.add_child(button("HELP",show_help,64))
	top.add_child(button("MENU",show_menu,70))
	info.position = Vector2(22,68)
	info.add_theme_font_size_override("font_size",16)
	info.add_theme_color_override("font_color",Color("ecd5a0"))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	hint.position = Vector2(22,92)
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("b9d0bd"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	var bottom = Panel.new()
	bottom.position = Vector2(0,640)
	bottom.size = Vector2(1280,80)
	bottom.add_theme_stylebox_override("panel",panel_style(Color("162f37")))
	root.add_child(bottom)
	var tabs = HBoxContainer.new()
	tabs.position = Vector2(14,647)
	tabs.add_theme_constant_override("separation",4)
	for name in ["work","build","troops"]:
		var key: String = name
		var b = button(name.to_upper(),func(): change_tab(key),78)
		b.custom_minimum_size.y = 60
		tabs.add_child(b)
	root.add_child(tabs)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(267,646)
	scroll.size = Vector2(805,70)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(dock)
	dock.add_theme_constant_override("separation",5)
	root.add_child(scroll)
	end_button = button("END ROUND",advance,174,true)
	end_button.position = Vector2(1092,647)
	end_button.size = Vector2(174,61)
	root.add_child(end_button)
	context.position = Vector2(278,582)
	context.add_theme_constant_override("separation",8)
	root.add_child(context)
	toast.position = Vector2(220,124)
	toast.size = Vector2(840,45)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_font_size_override("font_size",17)
	toast.add_theme_color_override("font_color",Color("ffe6ae"))
	toast.add_theme_color_override("font_shadow_color",Color("102c36"))
	toast.add_theme_constant_override("shadow_offset_x",2)
	toast.add_theme_constant_override("shadow_offset_y",2)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast)
	var camera_buttons = VBoxContainer.new()
	camera_buttons.position = Vector2(1218,472)
	camera_buttons.add_child(button("+",func(): zoom_at(Vector2(640,360),1.15),44))
	camera_buttons.add_child(button("-",func(): zoom_at(Vector2(640,360),1.0/1.15),44))
	camera_buttons.add_child(button("FIT",reset_camera,44))
	root.add_child(camera_buttons)

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	var names = {"food":"F","wood":"W","stone":"S","iron":"I","silver":"C"}
	for k in cost: parts.append(str(cost[k])+names[k])
	return " ".join(parts)

func rebuild_dock() -> void:
	clear_children(dock)
	if model.phase == "combat":
		for item in [["FOCUS","focus"],["CHARGE","charge"],["RETREAT","retreat"]]:
			var key: String = item[1]
			var b = button(item[0],func(): result(model.command(key)); rebuild_dock(),106)
			b.disabled = model.commands <= 0
			dock.add_child(b)
		dock.add_child(button("2x" if speed == 1 else "1x",func(): speed = 2 if speed == 1 else 1; rebuild_dock(),60))
		dock.add_child(button("RESUME" if paused else "PAUSE",func(): paused = not paused; rebuild_dock(),84))
		return
	if model.phase in ["preparation","aftermath"]:
		dock.add_child(label("Tap a soldier, then a free tile to reposition.\nBlue rings show your defenders; gold outlines show range.",16))
		return
	if model.phase in ["victory","defeat"]:
		dock.add_child(button("RESULTS",show_results,130))
		return
	match tab:
		"work":
			for item in [["CHOP +4","wood"],["HUNT +5","food"],["QUARRY +3","stone"],["MINE +2","iron"],["TOOLS 3I 2W","tools"],["TRADE 2C","trade"],["REPAIR 3W","repair"],["EXPLORE 3F","explore"]]:
				var key: String = item[1]
				var b = button(item[0],func(): result(model.action(key)); autosave(),101)
				b.disabled = model.actions < 1
				dock.add_child(b)
		"build":
			for kind in ["house","farm","lumber","well","pasture","smith","warehouse","tower","wall"]:
				var key: String = kind
				var spec = model.bdef(kind)
				var b = button(spec.name+"\n"+cost_text(spec.cost),func(): select_build(key),110)
				b.add_theme_font_size_override("font_size",13)
				b.disabled = model.actions < 1 or not model.can_pay(spec.cost)
				dock.add_child(b)
		"troops":
			for kind in ["shield","spear","archer","cavalry","cannon"]:
				var key: String = kind
				var b = button(model.udef(kind).name+"\n"+cost_text(model.training_cost(kind)),func(): select_unit(key),130)
				b.add_theme_font_size_override("font_size",13)
				b.disabled = model.actions < 1 or not model.can_pay(model.training_cost(kind))
				dock.add_child(b)

func refresh() -> void:
	if model.resources.is_empty(): return
	round_label.text = "FJORDWATCH  %02d / 10" % model.round_no
	for k in resource_labels: resource_labels[k].text = str(model.resources[k])
	worker_label.text = "WORKERS %d  |  PEOPLE %d  |  MORALE %d" % [model.actions,model.population,model.morale]
	var gain = model.production_preview()
	var net = gain.food-model.upkeep()
	var hall = model.get_hall()
	info.text = "%s  /  %s     Hearth %d     Food next round: %+d" % [model.season(),model.leader,int(hall.get("hp",0)),net]
	if model.phase == "planning": hint.text = model.event_text+"   "+threat_text()
	elif model.phase == "preparation": hint.text = "INVASION READY: "+threat_text()+"   Reposition soldiers freely, then SOUND HORN."
	elif model.phase == "combat": hint.text = "INVASION  |  %d enemies remaining  |  %d commands  |  %d kills" % [model.enemies.size()+model.spawn_queue.size(),model.commands,model.kills]
	elif model.phase == "aftermath": hint.text = "THE HEARTH HOLDS. Inspect damage; CONTINUE pays upkeep and starts the next round."
	else: hint.text = "THE LAST HEARTH ENDURES." if model.phase == "victory" else "THE HEARTH HAS FALLEN. A different layout may hold next time."
	match model.phase:
		"planning": end_button.text = "PRODUCE / END"
		"preparation": end_button.text = "SOUND HORN"
		"combat": end_button.text = "AUTO BATTLE"
		"aftermath": end_button.text = "CONTINUE"
		_: end_button.text = "FINAL SCORE"
	end_button.disabled = model.phase == "combat"
	# Avoid replacing pressed buttons on every combat tick.
	if current_phase != model.phase:
		current_phase = model.phase
		cancel_selection()
		rebuild_dock()
		if model.phase in ["victory","defeat"]: call_deferred("show_results")
	elif model.phase != "combat": rebuild_dock()

func threat_text() -> String:
	for r in [3,5,8,10]:
		if r >= model.round_no:
			var w = model.data.waves[str(r)]
			return "Next: R%d / %s / %d enemies" % [r,w.side.to_upper(),w.units.size()]
	return "Final invasion"

func change_tab(name: String) -> void:
	tab = name
	cancel_selection()
	rebuild_dock()

func select_build(kind: String) -> void:
	cancel_selection()
	world.selection = "build:"+kind
	world.build_rotation = 0
	world.show_grid = true
	notify(model.bdef(kind).name+": "+model.bdef(kind).desc)
	context.add_child(button("ROTATE",rotate_selection,92))
	context.add_child(button("PLACE · 1 worker",confirm_placement,168,true))
	context.add_child(button("CANCEL",cancel_selection,90))

func select_unit(kind: String) -> void:
	cancel_selection()
	world.selection = "train:"+kind
	world.show_grid = true
	notify(model.udef(kind).desc)
	context.add_child(button("RECRUIT HERE",confirm_placement,172,true))
	context.add_child(button("CANCEL",cancel_selection,90))

func rotate_selection() -> void:
	world.build_rotation = (world.build_rotation+1)%4

func confirm_placement() -> void:
	if not model.inside(selected_cell): notify("Tap the board to choose the footprint first."); return
	var error = ""
	if world.selection.begins_with("build:"):
		error = model.build(world.selection.trim_prefix("build:"),selected_cell,world.build_rotation)
	elif world.selection.begins_with("train:"):
		error = model.train(world.selection.trim_prefix("train:"),selected_cell)
	if error != "": notify(error); return
	cancel_selection()
	autosave()

func cancel_selection() -> void:
	world.selection = ""
	world.moving_id = -1
	world.selected_building = -1
	world.show_grid = false
	selected_cell = Vector2i(-100,-100)
	clear_children(context)

func result(error: String) -> void:
	if error != "": notify(error)

func advance() -> void:
	cancel_selection()
	match model.phase:
		"planning":
			model.end_planning()
			notify(model.report)
		"preparation": model.start_combat(); timer = 0.0; paused = false
		"aftermath": model.finish_round(); notify(model.event_text)
		_: show_results()
	autosave()

func pick(cell: Vector2i) -> void:
	if not model.inside(cell): cancel_selection(); return
	world.hover = cell
	if world.selection != "":
		selected_cell = cell
		if world.selection.begins_with("build:"):
			var error = model.placement_error(world.selection.trim_prefix("build:"),cell,world.build_rotation)
			if error != "": notify(error)
		return
	if world.moving_id >= 0:
		var error = model.move_unit(world.moving_id,cell)
		result(error)
		if error == "": cancel_selection(); autosave()
		return
	var soldier = model.unit_at(cell,model.units)
	if not soldier.is_empty() and model.phase in ["planning","preparation"]:
		world.moving_id = soldier.id
		world.show_grid = true
		notify(model.udef(soldier.kind).name+": tap a free tile to deploy. Repositioning costs no workers.")
		clear_children(context)
		context.add_child(button("CANCEL MOVE",cancel_selection,150))
		return
	var b = model.building_at(cell)
	clear_children(context)
	if not b.is_empty():
		world.selected_building = b.id
		notify(model.bdef(b.kind).name+" (%d/%d HP): " % [b.hp,b.max_hp]+model.bdef(b.kind).desc)
		if model.phase == "planning" and b.kind != "hall":
			var id: int = b.id
			context.add_child(button("DISMANTLE · 1 worker",func(): result(model.demolish(id)); cancel_selection(); autosave(),214))
		context.add_child(button("CLOSE",cancel_selection,80))
	else: world.selected_building = -1

func _input(event: InputEvent) -> void:
	# End camera gestures even when a release lands on a toolbar button.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
			call_deferred("finish_pointer_release")
	if modal != null:
		touches.clear()
		pinching = false
		dragging = false
		return
	if event is InputEventScreenTouch:
		if event.pressed: touches[event.index] = event.position
		else: touches.erase(event.index)
		if touches.size() >= 2: pinching = true; dragging = false
		elif pinching:
			pinch_cooldown = .3
			if touches.is_empty(): pinching = false
	if event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() >= 2:
			var before: Array = touches.values()
			var old_distance: float = before[0].distance_to(before[1])
			touches[event.index] = event.position
			var after: Array = touches.values()
			var new_distance: float = after[0].distance_to(after[1])
			if old_distance > 10: zoom_at((after[0]+after[1])*.5,new_distance/old_distance)
			get_viewport().set_input_as_handled()
		else: touches[event.index] = event.position

func finish_pointer_release() -> void:
	dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if modal != null: return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE: cancel_selection()
			KEY_R: rotate_selection()
			KEY_SPACE:
				if model.phase == "combat": paused = not paused; rebuild_dock()
			KEY_G: world.show_grid = not world.show_grid
	if event is InputEventMouseButton:
		if pinching or pinch_cooldown > 0: return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_at(event.position,1.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_at(event.position,1/1.1)
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				dragging = true
				drag_start = event.position
				drag_last = event.position
				panning = event.button_index != MOUSE_BUTTON_LEFT or (world.selection == "" and world.moving_id < 0)
			else:
				if dragging and drag_start.distance_to(event.position) < 9 and event.button_index == MOUSE_BUTTON_LEFT: pick(world.cell_at(event.position))
				dragging = false
	if event is InputEventMouseMotion:
		if pinching or pinch_cooldown > 0: return
		if dragging:
			if panning and drag_start.distance_to(event.position) >= 9:
				world.position += event.position-drag_last
				clamp_camera()
			elif world.selection != "":
				selected_cell = world.cell_at(event.position)
			drag_last = event.position
		world.hover = world.cell_at(event.position) if world.selection == "" or dragging else selected_cell

func zoom_at(point: Vector2,factor: float) -> void:
	var old_scale = world.scale.x
	var new_scale = clampf(old_scale*factor,.85,2.7)
	world.position = point-(point-world.position)*(new_scale/old_scale)
	world.scale = Vector2(new_scale,new_scale)
	clamp_camera()

func clamp_camera() -> void:
	world.position.x = clampf(world.position.x,100,1180)
	world.position.y = clampf(world.position.y,-450,420)

func reset_camera() -> void:
	world.position = base_world_position
	world.scale = Vector2(1.35,1.35)

func _process(delta: float) -> void:
	pinch_cooldown = maxf(0,pinch_cooldown-delta)
	if toast_time > 0:
		toast_time -= delta
		toast.modulate.a = minf(1,toast_time)
	if model.phase == "combat" and not paused and modal == null:
		timer += delta*speed
		world.combat_interval = .48/speed
		if timer >= .48:
			timer -= .48
			model.combat_step()
	if shake > 0:
		shake = maxf(0,shake-delta)
		world.render_shake = Vector2(sin(shake*130),cos(shake*110))*shake*4
	else:
		world.render_shake = Vector2.ZERO

func feedback(kind: String,cell: Vector2i,detail: String) -> void:
	if kind == "projectile": play_sound("shot")
	elif sounds.has(kind): play_sound(kind)
	if kind == "boom": shake = .18
	if kind == "place":
		if OS.has_feature("android"): Input.vibrate_handheld(18)
	if kind == "gain":
		var resource = detail if detail in resource_labels else "food"
		var icon = TextureRect.new()
		icon.texture = load("res://assets/res_"+resource+".png")
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = world.to_global(world.iso(cell))
		icon.size = Vector2(26,26)
		root.add_child(icon)
		var tw = create_tween()
		tw.tween_property(icon,"position",resource_labels[resource].global_position,.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(icon.queue_free)

func play_sound(kind: String) -> void:
	if muted or not sounds.has(kind) or audio_players.is_empty(): return
	var player: AudioStreamPlayer = audio_players[audio_index%audio_players.size()]
	audio_index += 1
	player.stream = sounds[kind]
	player.play()

func notify(message: String) -> void:
	toast.text = message
	toast_time = 7.0
	toast.modulate.a = 1

func autosave() -> bool:
	if not model.save_game():
		notify("Could not save. Check available device storage.")
		return false
	return true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]:
		if not model.resources.is_empty(): model.save_game()
		if what == NOTIFICATION_WM_CLOSE_REQUEST: get_tree().quit()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal != null: close_modal()
		else: show_menu()

func close_modal() -> void:
	dragging = false
	touches.clear()
	pinching = false
	if modal != null:
		modal.queue_free()
		modal = null

func popup(title: String,body: String) -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var shade = ColorRect.new()
	shade.color = Color(0.02,.08,.1,.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel = PanelContainer.new()
	panel.position = Vector2(260,130)
	panel.size = Vector2(760,460)
	panel.add_theme_stylebox_override("panel",panel_style(Color("18353e"),Color("b59e67")))
	modal.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	column.add_child(label(title,29,Color("edc783")))
	var text = label(body,17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 718
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(text)
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation",10)
	column.add_child(buttons)
	buttons.add_child(button("BACK TO ESTATE",close_modal,170,true))
	return column

func show_help() -> void:
	popup("BUILD THE BOARD. HOLD THE HEARTH.","1. Each round, spend your workers on resources, buildings or soldiers.\n2. BUILD: choose a shape, tap the land, ROTATE, then PLACE. Every occupied cell matters.\n3. Farms slow invaders; houses and walls block them. A blocked enemy attacks the obstacle.\n4. Farms near water or sheep yield more. High ground improves forges and archers.\n5. Tap a soldier, then a free tile to reposition. Range outlines show where it can attack.\n6. PRODUCE ends planning. Invasion rounds: 3, 5, 8, 10. SOUND HORN begins automatic combat.\n7. Feed people and soldiers every round. Winter reduces crops. Protect the central great hall.\n\nDrag open ground to pan; pinch or + / - to zoom. R rotates; Space pauses battle.\nResource costs: F food / W timber / S stone / I iron / C silver. No purchases or ads.")

func show_menu() -> void:
	var column = popup("THE JARL'S TABLE", "Leader: "+model.leader+"    |    Seed: "+str(model.seed_value)+"\nObjective: "+objective_text()+"\n\nThe estate autosaves after actions and rounds, before an invasion, and when the app pauses.\nSave preserves the exact combat tick. Loading replaces the current session.\n\nVersion 0.2 — native Godot vertical slice. Art and audio are original procedural assets.")
	var row = HBoxContainer.new()
	column.add_child(row)
	row.add_child(button("SAVE",func():
		if autosave(): close_modal(); notify("Settlement saved.")
	,96))
	var load_button = button("LOAD",func():
		if model.load_game():
			cancel_selection()
			timer = 0
			paused = false
			world.motions.clear()
			world.effects.clear()
			close_modal()
			notify("Settlement restored.")
		else: notify("Save could not be read; current settlement preserved.")
	,96)
	load_button.disabled = not FileAccess.file_exists(model.save_path)
	row.add_child(load_button)
	row.add_child(button("NEW GAME",confirm_new_game,120))
	row.add_child(button("SOUND OFF" if not muted else "SOUND ON",func(): muted = not muted; show_menu(),125))
	row.add_child(button("SCOUT",show_scout,94))

func objective_text() -> String:
	match model.objective:
		"Harvest": return "Store at least 25 food when the last invasion ends (+40)."
		"Fortress": return "Keep at least 4 wall sections / towers standing (+40)."
		_: return "Finish with 7 people and morale 7 or higher (+40)."

func show_scout() -> void:
	var rows = "Enemy schedules are fixed and visible. They do not scale with your army.\n\n"
	for r in [3,5,8,10]:
		var wave = model.data.waves[str(r)]
		var counts: Dictionary = {}
		for k in wave.units: counts[k] = counts.get(k,0)+1
		var parts: PackedStringArray = []
		for k in counts: parts.append(str(counts[k])+" "+model.udef(k).name)
		rows += "ROUND %d / %s\n%s\n\n" % [r,wave.side.to_upper(),", ".join(parts)]
	rows += "Raiders seek stores; huscarls resist arrows; sappers break walls; firebrands spread fire."
	popup("SCOUT REPORT",rows)

func confirm_new_game() -> void:
	var col = popup("LIGHT A NEW HEARTH?","This replaces the current settlement and its autosave.\n\nThe slice uses one river-valley map. A new seed changes the leader, initial resources and special objective.\n\nTo keep the current run, return to the estate.")
	col.add_child(button("START NEW SETTLEMENT",func():
		session_seed = int(Time.get_unix_time_from_system())%100000
		model.new_game(session_seed)
		cancel_selection()
		timer = 0
		paused = false
		world.motions.clear()
		world.effects.clear()
		close_modal()
		reset_camera()
		autosave()
	,260,true))

func show_results() -> void:
	var won = model.phase == "victory"
	if model.phase not in ["victory","defeat"]: return
	var body = "Your settlement survived all ten rounds." if won else "The great hall fell. Walls buy time; firing lanes and reserves turn time into victory."
	body += "\n\nFINAL SCORE  %d\nResidents %d  ·  Standing buildings %d  ·  Food %d\nSurviving soldiers %d  ·  Enemies defeated %d  ·  Buildings lost %d\n\nSpecial objective: +%d\n%s\n\nScoring: people 15, buildings 8, food 1, soldiers 10, defeats 2 each; lost buildings -12; victory +100." % [model.score,model.population,model.buildings.size(),model.resources.food,model.units.size(),model.kills,model.lost_buildings,model.objective_bonus(),objective_text()]
	var col = popup("THE LAST HEARTH" if won else "ASHES OF THE FJORD",body)
	col.add_child(button("PLAY ANOTHER SETTLEMENT",confirm_new_game,286,true))
