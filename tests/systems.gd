extends SceneTree

var failed := 0
var passed := 0

func check(value: bool, description: String) -> void:
	if value:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.save_enabled = false
	game.store.path = "user://test-progress-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	await process_frame
	check(game.screen == "title" and game.menu.visible, "startup shows title")
	var elapsed: float = game.elapsed
	game._physics_process(2)
	check(game.elapsed == elapsed, "title freezes game")
	game.menu_action("solo")
	check(game.screen == "play" and game.solo and not game.menu.visible, "solo starts game")
	game.show_pause()
	var pos: Vector2 = game.buddies[0].position
	game._physics_process(1)
	check(game.buddies[0].position == pos and game.elapsed == 0, "pause freezes physics and timer")
	game.menu_action("help")
	check(game.screen == "help", "help opens from pause")
	game.menu_action("back")
	check(game.screen == "pause", "help returns to pause")
	game.menu_action("resume")
	check(game.screen == "play", "pause resumes")
	game.menu_action("coop")
	check(not game.solo and game.stage == 1, "coop starts fresh game")
	game.set_physics_process(false)
	check(game.store.write(5, 12345, true), "atomic save succeeds")
	var saved: Dictionary = game.store.read()
	check(saved.get("stage") == 5 and saved.get("seed") == 12345, "save round trip")
	game.menu_action("continue")
	check(game.stage == 5 and game.seed_number == 12345 and game.solo, "continue restores run")
	var old_pool: Rect2 = game.pools[0].rect
	game.menu_action("retry")
	check(game.pools[0].rect == old_pool and game.collected == 0, "retry retains layout and clears progress")
	var invalid := ConfigFile.new()
	invalid.set_value("run", "version", 1)
	invalid.set_value("run", "stage", "not a number")
	invalid.save(game.store.path)
	check(game.store.read().is_empty(), "invalid save falls back safely")
	invalid.set_value("run", "version", 999)
	invalid.save(game.store.path)
	check(game.store.read().is_empty(), "unknown save version rejected")
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1
	Input.parse_input_event(stick)
	await process_frame
	var controls = load("res://scripts/controls.gd")
	check(controls.read(true, 1, 1).x > 0.9, "solo gamepad controls selected blue buddy")
	check(controls.read(true, 1, 0) == Vector2.ZERO, "inactive solo buddy receives no input")
	check(controls.read(false, 0, 1).x == 0, "first gamepad does not move second co-op buddy")
	stick.axis_value = 0
	Input.parse_input_event(stick)
	var motor = game.buddies[0]
	motor.reset_motion()
	motor.coyote = 0.08
	motor.step(1.0/60, 0, true)
	check(motor.jumped and motor.velocity.y < -600, "coyote window accepts jump after edge")
	motor.step(1.0/60, 0, false)
	check(motor.velocity.y >= -300, "release cuts jump height")
	motor.reset_motion()
	motor.coyote = 0
	motor.step(1.0/60, 0, true)
	check(motor.jump_buffer > 0, "airborne press buffers next landing jump")
	check(motor.collision_mask == 1 and motor.collision_layer == 2, "buddies cannot block each other")
	DirAccess.remove_absolute(game.store.path)
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
