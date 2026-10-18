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

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	var released := event.duplicate()
	released.pressed = false
	root.push_input(released,true)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.save_enabled = false
	game.store.path = "user://no-save-ui-test-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	await process_frame
	await process_frame
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await process_frame
	check(game.screen == "play" and game.run_mode == "lessons", "Enter activates focused new solo game")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await process_frame
	check(game.screen == "pause" and game.menu.visible, "Escape opens actual pause menu")
	await process_frame
	var settings_button: Button
	for child in game.menu.box.get_children():
		if child is Button and child.text == "游戏设置":
			settings_button = child
	check(settings_button != null, "pause has settings button")
	if settings_button:
		click(settings_button)
		await process_frame
		check(game.screen == "settings", "mouse click activates settings button")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await process_frame
	check(game.screen == "pause", "Escape returns from settings to pause")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await process_frame
	check(game.screen == "play", "Escape resumes actual game")
	key(KEY_F1,true)
	key(KEY_F1,false)
	await process_frame
	check(game.screen == "help", "F1 opens help")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await process_frame
	check(game.screen == "pause", "help Escape returns to safe pause")
	print("RESULT: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
