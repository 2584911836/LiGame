extends SceneTree
var passed := 0
var failed := 0

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func press(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.save_enabled = false
	game.settings.path = "user://input-test-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var controls = load("res://scripts/controls.gd")
	check(controls.valid_bindings({}), "default bindings valid")
	check(not controls.valid_bindings({"orange_left":KEY_D}), "duplicate action key rejected")
	check(not controls.valid_bindings({"orange_left":KEY_R}), "system hotkey rejected")
	check(not controls.valid_bindings({"orange_left":KEY_SPACE}), "space cannot shadow solo jump with movement")
	check(not controls.valid_bindings({"unknown":KEY_Q}), "unknown action rejected")
	game.menu_action("bindings")
	game.menu_action("bind:orange_left")
	press(KEY_J,true)
	await process_frame
	press(KEY_J,false)
	check(game.screen == "bindings" and game.settings.bindings.get("orange_left") == KEY_J, "real capture remaps orange left")
	game.screen = "play"
	game.menu.hide()
	press(KEY_J,true)
	await process_frame
	check(controls.read(true,0,0).x < -0.9, "new key controls selected solo buddy")
	check(controls.read(false,0,0).x < -0.9, "new key controls co-op orange")
	press(KEY_J,false)
	press(KEY_A,true)
	await process_frame
	check(controls.read(false,0,0).x == 0, "old key removed from co-op action")
	press(KEY_A,false)
	game.menu_action("bind:orange_left")
	press(KEY_D,true)
	await process_frame
	press(KEY_D,false)
	check(game.screen == "binding_capture" and game.settings.bindings.orange_left == KEY_J, "duplicate capture leaves previous mapping intact")
	press(KEY_ESCAPE,true)
	await process_frame
	press(KEY_ESCAPE,false)
	check(game.screen == "bindings", "escape cancels capture")
	check(game.settings.write(), "custom mapping saves")
	game.settings.bindings.clear()
	game.settings.read()
	check(game.settings.bindings.get("orange_left") == KEY_J, "custom mapping survives reload")
	game.menu_action("bindings_reset")
	check(game.settings.bindings.is_empty(), "restore default clears overrides")
	game.screen = "play"
	game.menu.hide()
	press(KEY_A,true)
	await process_frame
	check(controls.read(false,0,0).x < -0.9, "restore default reinstalls original input")
	press(KEY_A,false)
	game.using_gamepad = false
	game.joy_connection_changed(0,false)
	check(game.screen == "play", "keyboard play ignores unrelated controller disconnect")
	game.using_gamepad = true
	game.joy_connection_changed(0,false)
	check(game.screen == "pause" and not game.input_notice.is_empty(), "controller disconnect pauses with explanation")
	game.menu_action("resume")
	check(game.screen == "play" and game.input_notice.is_empty(), "resume clears disconnect notice")
	DirAccess.remove_absolute(game.settings.path)
	print("RESULT: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
