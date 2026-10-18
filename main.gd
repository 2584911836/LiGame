extends Node2D

const FLOOR_Y := 610.0
const SPEED := 245.0
const JUMP := -720.0
const GRAVITY := 1450.0
const QUIPS := ["搭子齐心，其利断金——也可能一起掉进汤里。", "温馨提示：岩浆不是免费温泉。", "本队仅有两个脑细胞，请轮流使用。", "请勿把你的搭子放进微波炉。"]
const BuddyScript = preload("res://scripts/buddy.gd")
const Controls = preload("res://scripts/controls.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const LevelGenerator = preload("res://scripts/level_generator.gd")
const GameView = preload("res://scripts/game_view.gd")
const Settings = preload("res://scripts/settings.gd")
const Sounds = preload("res://scripts/sounds.gd")
const Menu = preload("res://scripts/menu.gd")
var buddies: Array[CharacterBody2D] = []
var platforms: Array[Rect2] = []
var pools: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var stage := 1
var seed_number := 1
var selected := 0
var solo := true
var deaths := 0
var collected := 0
var gate_open := false
var plates_activated: Array[bool] = [false, false]
var won := false
var transition := 0.0
var message := ""
var font: Font = preload("res://assets/ui-font.otf")
var rng := RandomNumberGenerator.new()
var screen := "title"
var help_return := "title"
var menu: CanvasLayer
var store := SaveStore.new()
var save_enabled := true
var elapsed := 0.0
var run_mode := "endless"
var devices: Array = []
var level_title := ""
var level_hint := ""
var theme_index := 0
var completed := false
var sound: Node
var view: Node2D
var settings := Settings.new()
var settings_return := "title"
var pending_binding := ""
var input_notice := ""
var using_gamepad := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "play" and menu != null:
		show_pause()


func _ready() -> void:
	seed_number = int(Time.get_unix_time_from_system()) % 1000000
	settings.read()
	view = GameView.new()
	view.game = self
	add_child(view)
	sound = Sounds.new()
	add_child(sound)
	apply_settings()
	Controls.setup()
	Controls.apply_bindings(settings.bindings)
	Input.joy_connection_changed.connect(joy_connection_changed)
	for i in 2:
		var body := BuddyScript.new()
		add_child(body)
		buddies.append(body)
	generate()
	menu = Menu.new()
	add_child(menu)
	menu.chosen.connect(menu_action)
	show_title()

func show_title() -> void:
	screen = "title"
	var buttons: Array = []
	if not store.read().is_empty():
		buttons.append(["继续冒险", "continue"])
	buttons.append_array([["单人教学 · 六关入职", "solo"], ["双人教学 · 六关团建", "coop"], ["随机挑战 · 无限工单", "endless"], ["指定种子挑战", "seed"], ["游戏设置", "settings"], ["玩法与操作", "help"], ["退出游戏", "quit"]])
	menu.show_screen("冷热搭子", "摸鱼闯关队 · 两个搭子，一起下班！\n支持键盘与手柄 · Enter 确认 · 方向键选择", buttons)

func show_pause() -> void:
	screen = "pause"
	menu.show_screen("休息一下", input_notice if not input_notice.is_empty() else "当前关卡已暂停。返回标题后可从本关起点继续。", [["继续游戏", "resume"], ["玩法与操作", "help"], ["游戏设置", "settings"], ["重开本关", "retry"], ["返回标题", "title"]])

func menu_action(action: String) -> void:
	if action.begins_with("bind:"):
		pending_binding = action.trim_prefix("bind:")
		screen = "binding_capture"
		menu.show_screen("设置：" + Controls.ACTION_LABELS[pending_binding], "按下新的操作键，Esc 取消。\n不能重复使用其他动作键或 M/R/N/Tab 等系统键。", [["取消", "bindings"]])
		return
	match action:
		"solo", "coop", "endless":
			solo = action != "coop"
			run_mode = "endless" if action == "endless" else "lessons"
			selected = 0
			stage = 1
			deaths = 0
			seed_number = int(Time.get_unix_time_from_system()) % 1000000
			generate()
			resume_play()
			checkpoint()
		"continue":
			var saved := store.read()
			if saved.is_empty():
				show_title()
				return
			stage = saved.stage
			seed_number = saved.seed
			solo = saved.solo
			run_mode = saved.get("mode", "endless")
			selected = 0
			generate()
			resume_play()
		"sound":
			settings.volume = 0 if settings.volume > 0 else 0.75
			apply_settings()
			persist_settings()
			show_settings()
		"settings":
			settings_return = screen
			show_settings()
		"volume":
			settings.volume = fmod(settings.volume + 0.25,1.25)
			apply_settings()
			persist_settings()
			show_settings()
		"motion":
			settings.reduced_motion = not settings.reduced_motion
			persist_settings()
			show_settings()
		"bindings_back":
			show_settings()
		"settings_back":
			if settings_return == "title":
				show_title()
			else:
				show_pause()
		"bindings":
			show_bindings()
		"bindings_reset":
			settings.bindings.clear()
			Controls.apply_bindings(settings.bindings)
			persist_settings()
			show_bindings()
		"seed":
			screen = "seed"
			menu.seed_entry()
		"start_seed":
			var value: int = menu.read_seed()
			if value < 0:
				return
			seed_number = value
			stage = 1
			deaths = 0
			selected = 0
			run_mode = "endless"
			solo = true
			generate()
			resume_play()
			checkpoint()
		"resume":
			resume_play()
		"retry":
			generate()
			resume_play()
		"title":
			checkpoint()
			show_title()
		"help":
			help_return = screen
			screen = "help"
			menu.show_screen("搭子入职指南", "%s\n单人任意一组键／空格跳，Tab 换人；M 切换模式。\n手柄：左摇杆移动，A 跳跃；单人 X 换人，Start 暂停。\n各踩一次同色踏板 → 收齐四颗宝石 → 两人进入同色门。\n橙色怕蓝池，蓝色怕橙池，紫池谁碰谁翻车！\nEsc 暂停，F1 帮助，F11 全屏；R 重开，N 新冒险。\n自动保存关数和种子，继续游戏从本关起点开始。" % Controls.legend(settings.bindings), [["明白了", "back"]])
		"back":
			if help_return == "title":
				show_title()
			else:
				show_pause()
		"quit":
			get_tree().quit()

func show_settings() -> void:
	screen = "settings"
	menu.show_screen("游戏设置", "设置自动保存在本机，可随时修改。", [["键盘按键设置", "bindings"], ["音量：%d%%（点击切换）" % int(settings.volume*100), "volume"], ["静音：%s" % ("开" if settings.volume == 0 else "关"), "sound"], ["减少动态效果：%s" % ("开" if settings.reduced_motion else "关"), "motion"], ["返回", "settings_back"]])

func show_bindings() -> void:
	screen = "bindings"
	pending_binding = ""
	var buttons: Array = []
	for action in Controls.DEFAULT_KEYS:
		var code: int = settings.bindings.get(action,Controls.DEFAULT_KEYS[action])
		buttons.append([Controls.ACTION_LABELS[action] + "：" + Controls.key_name(code), "bind:"+action])
	buttons.append_array([["恢复默认", "bindings_reset"],["返回设置", "bindings_back"]])
	menu.show_screen("键盘按键设置", "单人可使用任意一组键，空格也可跳跃。",buttons)

func persist_settings() -> void:
	if save_enabled and not settings.write():
		message = "设置保存失败，本次设置仍有效。"

func _input(event: InputEvent) -> void:
	if screen == "binding_capture" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			show_bindings()
			return
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var updated := settings.bindings.duplicate()
		updated[pending_binding] = code
		if not Controls.valid_bindings(updated):
			menu.show_screen("这个按键暂时不能使用", "选择一个没有被其他动作占用的字母、数字或方向键。\nM/R/N/Tab 等系统键不能改为动作键；Esc 取消。", [["取消", "bindings"]])
			return
		settings.bindings = updated
		Controls.apply_bindings(updated)
		persist_settings()
		show_bindings()
	elif screen == "play":
		if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
			using_gamepad = true
		elif event is InputEventKey and event.pressed:
			using_gamepad = false

func joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected and using_gamepad and screen == "play":
		input_notice = "手柄已断开。重新连接后继续，或使用键盘操作。"
		show_pause()

func apply_settings() -> void:
	sound.enabled = settings.volume > 0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, settings.volume)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func refresh_view() -> void:
	if view != null:
		view.queue_redraw()

func resume_play() -> void:
	input_notice = ""
	screen = "play"
	menu.hide()
	for buddy in buddies:
		buddy.jump_was_held = true

func checkpoint() -> void:
	if save_enabled and not store.write(stage, seed_number, solo, run_mode):
		message = "存档写入失败，本次仍可继续游玩。"

func add_platform(rect: Rect2) -> void:
	platforms.append(rect)
	var body := StaticBody2D.new()
	body.add_to_group("terrain")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)

func generate() -> void:
	for node in get_tree().get_nodes_in_group("terrain"):
		node.free()
	platforms.clear()
	pools.clear()
	gems.clear()
	var data := LevelGenerator.make(seed_number, stage, run_mode)
	add_platform(Rect2(0, FLOOR_Y, 1152, 110))
	add_platform(Rect2(-30, 0, 30, 720))
	add_platform(Rect2(1152, 0, 30, 720))
	for rect in data.platforms:
		add_platform(rect)
	pools.assign(data.pools)
	gems.assign(data.gems)
	devices = data.devices
	level_title = data.title
	level_hint = data.hint
	theme_index = data.theme
	completed = false
	if view != null:
		view.particles.clear()
	elapsed = 0
	collected = 0
	gate_open = false
	plates_activated = [false, false]
	won = false
	transition = 0
	message = QUIPS[(stage - 1) % QUIPS.size()]
	reset_buddies()

func reset_buddies() -> void:
	for i in 2:
		buddies[i].position = Vector2(65 + i * 48, 575)
		buddies[i].reset_motion()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_buddy") and screen == "play":
		selected = 1 - selected
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if screen == "play":
			show_pause()
		elif screen == "pause":
			resume_play()
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if screen == "play":
				show_pause()
			elif screen == "pause":
				resume_play()
			elif screen == "help":
				menu_action("back")
			elif screen == "settings":
				menu_action("settings_back")
			elif screen == "seed":
				show_title()
			elif screen in ["bindings", "binding_capture"]:
				show_settings()
		KEY_F11:
			settings.fullscreen = not settings.fullscreen
			apply_settings()
			persist_settings()
		KEY_F1:
			if screen in ["title", "play", "pause"]:
				menu_action("help")
	if screen != "play":
		return
	match event.keycode:
		KEY_M:
			solo = not solo
			checkpoint()
		KEY_R:
			generate()
		KEY_N:
			run_mode = "endless"
			seed_number = (seed_number + 104729) % 1000000
			stage = 1
			generate()
			checkpoint()

func _physics_process(delta: float) -> void:
	if screen != "play":
		return
	elapsed += delta
	if won:
		transition += delta
		if transition > 1.8:
			if run_mode == "lessons" and stage >= 6:
				if not completed:
					completed = true
					screen = "complete"
					menu.show_screen("恭喜下班！", "六张工单全部完成！现在去挑战随机组合关卡吧。", [["开始随机挑战", "endless"], ["返回标题", "title"]])
				return
			stage += 1
			generate()
			checkpoint()
		refresh_view()
		return
	for device in devices:
		device.cooldown = maxf(0, device.cooldown - delta)
	for i in 2:
		var body := buddies[i]
		var control: Vector2 = Controls.read(solo, selected, i)
		for device in devices:
			if device.type == "wind" and device.rect.has_point(body.position):
				body.velocity.y -= 900 * delta
		body.step(delta, control.x, control.y > 0)
		if body.jumped:
			sound.play_cue("jump")
			view.burst(body.position + Vector2(0,20), Color.WHITE, 5)
		apply_devices(i)
		for pool in pools:
			if pool.rect.has_point(body.position + Vector2(0, 20)) and pool.kind != i:
				view.burst(body.position, view.color_for(i), 14)
				sound.play_cue("oops")
				deaths += 1
				message = "喝错汤了！搭子一起重生，宝石和门锁进度保留。"
				reset_buddies()
				refresh_view()
				return
		for gem in gems:
			if not gem.taken and gem.kind == i and body.position.distance_to(gem.pos) < 34:
				view.burst(gem.pos, view.color_for(i), 12)
				sound.play_cue("gem")
				gem.taken = true
				collected += 1
	update_objectives()
	refresh_view()

func apply_devices(buddy_id: int) -> void:
	var body := buddies[buddy_id]
	for device in devices:
		if device.type == "spring" and device.cooldown <= 0 and body.is_on_floor() and absf(body.position.x - device.pos.x) < 22 and absf(body.position.y + 21 - device.pos.y) < 8:
			body.velocity.y = -850
			device.cooldown = 0.35
			sound.play_cue("spring")
		if device.type == "bridge" and not device.active and buddy_id == device.kind and Rect2(device.pos - Vector2(18, 45), Vector2(36, 45)).has_point(body.position):
			device.active = true
			add_platform(device.bridge)
			sound.play_cue("gate")

func update_objectives() -> void:
	# Each matching plate latches separately so solo players can activate them in any order.
	for i in 2:
		if Rect2(96 + i * 59, 565, 40, 45).has_point(buddies[i].position):
			plates_activated[i] = true
	var was_open := gate_open
	gate_open = plates_activated[0] and plates_activated[1]
	if gate_open and not was_open:
		sound.play_cue("gate")
	if not won and gate_open and collected == gems.size() and at_exit(0) and at_exit(1):
		view.burst(Vector2(1040,560), view.color_for(0), 30)
		view.burst(Vector2(1100,560), view.color_for(1), 30)
		sound.play_cue("win")
		won = true
		message = "打卡成功！下一份离谱工单正在派送……"
	refresh_view()

func at_exit(i: int) -> bool:
	return Rect2(1020 + i * 60, 550, 40, 60).has_point(buddies[i].position)

func objective_status() -> String:
	if not gate_open:
		return "开门进度：橙色踏板%s / 蓝色踏板%s（各踩一次即可）" % ["已激活" if plates_activated[0] else "未激活", "已激活" if plates_activated[1] else "未激活"]
	if collected < gems.size():
		return "门已开启！还需收集 %d 颗宝石，角色只能收集同色宝石。" % (gems.size() - collected)
	return "宝石已齐！前往右侧同色出口：橙色%s / 蓝色%s" % ["已到达" if at_exit(0) else "未到达", "已到达" if at_exit(1) else "未到达"]
