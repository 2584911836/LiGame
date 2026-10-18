# End-to-end bot: real inputs, gravity, collisions, hazards, gems and doors.
# No position teleportation, fabricated gems, immunity or disabled assertions.
extends SceneTree
var game: Node
var failed := false
var completed := 0

func _initialize() -> void:
	call_deferred("run")

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func move_to(buddy_id: int, target: float) -> void:
	game.selected = buddy_id
	var body: CharacterBody2D = game.buddies[buddy_id]
	var limit := 240
	while absf(body.position.x - target) > 3 and limit > 0:
		var right: bool = body.position.x < target
		key(KEY_D, right)
		key(KEY_A, not right)
		await physics_frame
		limit -= 1
	key(KEY_D, false)
	key(KEY_A, false)
	await physics_frame
	if limit == 0:
		failed = true
		printerr("Movement timeout: buddy %d x=%f target=%f" % [buddy_id, body.position.x, target])

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	await process_frame
	for lesson in range(1, 7):
		game.menu_action("solo")
		game.stage = lesson
		game.generate()
		await solve("lesson %d" % lesson)
		if failed:
			break
	if not failed:
		for seed_id in seed_list():
			game.menu_action("endless")
			game.seed_number = seed_id
			game.generate()
			await solve("seed %d" % seed_id)
			if failed:
				break
	print("RESULT: %d complete stages; failure=%s" % [completed, failed])
	quit(1 if failed else 0)

func seed_list() -> Array:
	var seeds: Array = [0,42,12345,999999]
	if "--stress" in OS.get_cmdline_user_args():
		for i in 100:
			var value := (i * 7919 + 17) % 1000000
			if value not in seeds:
				seeds.append(value)
	return seeds

func solve(description: String) -> void:
	await frames(30)
	await move_to(0, 116)
	await move_to(1, 175)
	if not game.gate_open:
		failed = true
		printerr("Gate did not open: " + description)
		return
	var initial_deaths: int = game.deaths
	for buddy_id in 2:
		for gem in game.gems:
			await move_to(buddy_id, gem.pos.x - 115)
			await frames(65)
			key(KEY_W, true)
			await frames(2)
			await move_to(buddy_id, gem.pos.x)
			await frames(100)
			key(KEY_W, false)
			await frames(2)
			if game.deaths != initial_deaths:
				failed = true
				printerr("Bot hit hazard in %s, buddy %d, gem %s, pos %s" % [description, buddy_id, gem.pos, game.buddies[buddy_id].position])
				return
		# Exit area starts after the final pool. Jump off final ledge past it.
		key(KEY_W, true)
		await frames(2)
		await move_to(buddy_id, 1040 + buddy_id * 60)
		key(KEY_W, false)
		await frames(80)
		if buddy_id == 0 and not game.at_exit(0):
			failed = true
			printerr("Orange failed to reach exit: " + description)
			return
	if not game.won and game.screen != "complete":
		failed = true
		printerr("No victory in %s; gems=%d state=%s" % [description, game.collected, game.objective_status()])
		return
	completed += 1
	print("PASS: full physics traversal " + description)
