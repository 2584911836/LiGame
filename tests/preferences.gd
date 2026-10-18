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
	var game = load("res://main.tscn").instantiate()
	game.save_enabled = false
	game.settings.path = "user://test-settings-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.menu_action("settings")
	check(game.screen == "settings", "title opens preferences")
	game.settings.volume = 0.75
	game.menu_action("volume")
	check(game.settings.volume == 1 and game.sound.enabled, "volume cycles to full")
	game.menu_action("volume")
	check(game.settings.volume == 0 and not game.sound.enabled, "volume cycles to mute")
	game.menu_action("sound")
	check(game.settings.volume == 0.75 and game.sound.enabled, "unmute restores audible volume")
	game.settings.reduced_motion = false
	game.menu_action("motion")
	var particle_count: int = game.view.particles.size()
	game.view.burst(Vector2(50,50),Color.WHITE,20)
	check(game.settings.reduced_motion and game.view.particles.size() == particle_count, "reduced motion suppresses particle effects")
	check(game.settings.write(), "preferences save atomically")
	game.settings.volume = 0
	game.settings.reduced_motion = false
	game.settings.read()
	check(game.settings.volume == 0.75 and game.settings.reduced_motion, "preferences survive reload")
	var invalid := ConfigFile.new()
	invalid.set_value("audio","volume","loud")
	invalid.set_value("display","reduced_motion",123)
	invalid.save(game.settings.path)
	game.settings.read()
	check(game.settings.volume == 0.75 and game.settings.reduced_motion, "invalid preferences preserve safe values")
	game.menu_action("settings_back")
	check(game.screen == "title", "preferences return to title")
	game.menu_action("seed")
	var input := game.menu.box.get_node("SeedInput") as LineEdit
	input.text = "abc"
	game.menu_action("start_seed")
	check(game.screen == "seed", "invalid seed keeps input screen")
	input.text = "-1"
	game.menu_action("start_seed")
	check(game.screen == "seed", "negative seed rejected")
	input.text = "12345"
	game.menu_action("start_seed")
	check(game.screen == "play" and game.seed_number == 12345 and game.run_mode == "endless", "valid seed starts reproducible challenge")
	game.view.particles.clear()
	game.settings.reduced_motion = false
	game.view.burst(Vector2(50,50),Color.WHITE,20)
	check(game.view.particles.size() == 20, "effects enabled spawns particle burst")
	game.show_pause()
	game.menu_action("settings")
	game.menu_action("settings_back")
	check(game.screen == "pause", "in-game preferences return to pause")
	DirAccess.remove_absolute(game.settings.path)
	print("RESULT: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
