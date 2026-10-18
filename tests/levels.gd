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

func run() -> void:
	var generator = load("res://scripts/level_generator.gd")
	for lesson in range(1, 7):
		var data: Dictionary = generator.make(123, lesson, "lessons")
		var other: Dictionary = generator.make(999, lesson, "lessons")
		check(data == other, "lesson %d independent of random run seed" % lesson)
		check(data.gems.size() == 4, "lesson %d has balanced gems" % lesson)
	var game = load("res://main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.menu_action("solo")
	game.stage = 3
	game.generate()
	var bridge: Dictionary = game.devices[0]
	var count: int = game.platforms.size()
	game.buddies[1 - bridge.kind].position = bridge.pos - Vector2(0,21)
	game.apply_devices(1 - bridge.kind)
	check(not bridge.active, "wrong attribute cannot open bridge")
	game.buddies[bridge.kind].position = bridge.pos - Vector2(0,21)
	game.apply_devices(bridge.kind)
	check(bridge.active and game.platforms.size() == count + 1, "matching switch creates bridge collision")
	game.apply_devices(bridge.kind)
	check(game.platforms.size() == count + 1, "bridge cannot duplicate collision")
	game.generate()
	check(not game.devices[0].active, "retry clears bridge activation")
	game.stage = 6
	game.generate()
	game.won = true
	game._physics_process(2)
	check(game.screen == "complete" and game.stage == 6, "sixth lesson ends on completion menu")
	game.menu_action("endless")
	check(game.run_mode == "endless" and game.stage == 1 and game.screen == "play", "completion can start endless challenge")
	check(game.sound.clips.size() == 6 and game.sound.clips.gem.data.size() > 0, "procedural sound cues generated")
	game.show_pause()
	var previous: bool = game.sound.enabled
	game.menu_action("sound")
	check(game.sound.enabled != previous and game.screen == "pause", "pause menu toggles sound")
	# Older saves remain readable after adding mode metadata.
	game.store.path = "user://migration-test-%d.cfg" % OS.get_process_id()
	var old := ConfigFile.new()
	old.set_value("run", "version", 1)
	old.set_value("run", "stage", 3)
	old.set_value("run", "seed", 9)
	old.set_value("run", "solo", true)
	old.save(game.store.path)
	check(game.store.read().get("mode") == "endless", "v1 save migrates to endless mode")
	DirAccess.remove_absolute(game.store.path)
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
