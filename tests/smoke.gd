extends SceneTree

var game: Node
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	if not ok:
		printerr("FAIL: " + description)
		failures += 1
		return
	checks += 1
	print("PASS: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	await process_frame
	game.screen = "play"
	game.menu.hide()
	game.set_physics_process(false)
	check(game.buddies.size() == 2, "two playable characters")
	game.seed_number = 12345
	game.generate()
	var first: Rect2 = game.pools[0].rect
	game.generate()
	check(game.pools[0].rect == first, "seed reproduces map")
	for seed_id in 100:
		game.seed_number = seed_id
		game.generate()
		for i in 4:
			var ledge: Rect2 = game.platforms[i + 3]
			check(610 - ledge.position.y < 165 and game.pools[i].rect.size.x < 100, "seed %d obstacle %d within jump envelope" % [seed_id, i])
	game.buddies[0].position = Vector2(116, 589)
	game.buddies[1].position = Vector2(65, 589)
	game.update_objectives()
	check(game.plates_activated[0] and not game.gate_open, "orange plate remembers activation while blue is away")
	game.buddies[0].position = Vector2(200, 589)
	game.buddies[1].position = Vector2(175, 589)
	game.update_objectives()
	check(game.gate_open, "sequential solo plate activation unlocks exits")
	for gem in game.gems:
		game.buddies[gem.kind].position = gem.pos
		game._physics_process(0.0)
	check(game.collected == 4, "each character collects matching gems")
	var pool: Dictionary = game.pools[0]
	pool.kind = 0
	game.buddies[0].position = pool.rect.get_center() - Vector2(0,20)
	game.buddies[1].position = Vector2(170,580)
	var before: int = game.deaths
	game._physics_process(0.0)
	check(game.deaths == before, "orange survives orange pool")
	game.buddies[1].position = pool.rect.get_center() - Vector2(0,20)
	game._physics_process(0.0)
	check(game.deaths == before + 1 and game.collected == 4, "wrong pool respawns team and retains gems")
	game.buddies[0].position = Vector2(1040,579)
	game.buddies[1].position = Vector2(1100,579)
	game.update_objectives()
	check(game.won, "both exits with gems complete stage")
	game._physics_process(2.0)
	check(game.stage == 2 and game.collected == 0 and not game.gate_open, "next stage resets objective state")
	# Actual physics: take off from the floor and land back safely.
	game.reset_buddies()
	game.set_physics_process(true)
	for frame in 30:
		await physics_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	for frame in 12:
		await physics_frame
	event.pressed = false
	Input.parse_input_event(event)
	check(game.buddies[0].position.y < 540, "real input causes physics jump")
	for frame in 90:
		await physics_frame
	check(game.buddies[0].is_on_floor(), "jump lands on collision floor")
	# Regress the solo workflow using real input over physics frames.
	game.selected = 1
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	for frame in 16:
		await physics_frame
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
	check(game.plates_activated[1], "blue walks onto plate with real input")
	game.selected = 0
	event.pressed = true
	Input.parse_input_event(event)
	for frame in 12:
		await physics_frame
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
	check(game.gate_open, "solo real-input plate activation opens doors")
	# Fixture skips the already-covered obstacle section; walk into both exits.
	game.collected = 4
	game.buddies[0].position = Vector2(990,589)
	game.buddies[1].position = Vector2(1140,589)
	for frame in 3:
		await physics_frame
	event.pressed = true
	Input.parse_input_event(event)
	for frame in 12:
		await physics_frame
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
	check(game.at_exit(0) and not game.won, "orange waits in exit for blue")
	game.selected = 1
	event.physical_keycode = KEY_A
	event.pressed = true
	Input.parse_input_event(event)
	for frame in 10:
		await physics_frame
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
	check(game.won, "walking blue into exit triggers victory")
	for frame in 120:
		await physics_frame
	check(game.stage == 3, "victory advances stage through real physics frames")
	print("RESULT: %d passed, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
