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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "play" and menu != null:
		show_pause()


func _ready() -> void:
	seed_number = int(Time.get_unix_time_from_system()) % 1000000
	sound = Sounds.new()
	add_child(sound)
	Controls.setup()
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
	buttons.append_array([["单人教学 · 六关入职", "solo"], ["双人教学 · 六关团建", "coop"], ["随机挑战 · 无限工单", "endless"], ["玩法与操作", "help"], ["退出游戏", "quit"]])
	menu.show_screen("冷热搭子", "摸鱼闯关队 · 两个搭子，一起下班！\n支持键盘与手柄 · Enter 确认 · 方向键选择", buttons)

func show_pause() -> void:
	screen = "pause"
	menu.show_screen("休息一下", "当前关卡已暂停。返回标题后可从本关起点继续。", [["继续游戏", "resume"], ["玩法与操作", "help"], ["音效：%s" % ("开" if sound.enabled else "关"), "sound"], ["重开本关", "retry"], ["返回标题", "title"]])

func menu_action(action: String) -> void:
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
			sound.enabled = not sound.enabled
			show_pause()
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
			menu.show_screen("搭子入职指南", "单人：A/D 或方向键移动，W/↑/空格跳跃，Tab 换人。\n双人：橙色 A/D/W，蓝色方向键。M 切换模式。\n手柄：左摇杆移动，A 跳跃；单人 X 换人，Start 暂停。\n各踩一次同色踏板 → 收齐四颗宝石 → 两人进入同色门。\n橙色怕蓝池，蓝色怕橙池，紫池谁碰谁翻车！\nEsc 暂停，F1 帮助，F11 全屏；R 重开，N 新冒险。\n自动保存关数和种子，继续游戏从本关起点开始。", [["明白了", "back"]])
		"back":
			if help_return == "title":
				show_title()
			else:
				show_pause()
		"quit":
			get_tree().quit()

func resume_play() -> void:
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
		KEY_F11:
			var mode := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_F1:
			if screen != "help":
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
		queue_redraw()
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
		apply_devices(i)
		for pool in pools:
			if pool.rect.has_point(body.position + Vector2(0, 20)) and pool.kind != i:
				sound.play_cue("oops")
				deaths += 1
				message = "喝错汤了！搭子一起重生，宝石和门锁进度保留。"
				reset_buddies()
				queue_redraw()
				return
		for gem in gems:
			if not gem.taken and gem.kind == i and body.position.distance_to(gem.pos) < 34:
				sound.play_cue("gem")
				gem.taken = true
				collected += 1
	update_objectives()
	queue_redraw()

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
		sound.play_cue("win")
		won = true
		message = "打卡成功！下一份离谱工单正在派送……"
	queue_redraw()

func at_exit(i: int) -> bool:
	return Rect2(1020 + i * 60, 550, 40, 60).has_point(buddies[i].position)

func objective_status() -> String:
	if not gate_open:
		return "开门进度：橙色踏板%s / 蓝色踏板%s（各踩一次即可）" % ["已激活" if plates_activated[0] else "未激活", "已激活" if plates_activated[1] else "未激活"]
	if collected < gems.size():
		return "门已开启！还需收集 %d 颗宝石，角色只能收集同色宝石。" % (gems.size() - collected)
	return "宝石已齐！前往右侧同色出口：橙色%s / 蓝色%s" % ["已到达" if at_exit(0) else "未到达", "已到达" if at_exit(1) else "未到达"]

func label_at(pos: Vector2, text: String, size := 20, color := Color("23354d")) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 720), LevelGenerator.THEMES[theme_index][1])
	for i in 8:
		draw_circle(Vector2(i * 180 + 40, 280 + (i % 3) * 50), 90, Color("e1eef3"))
	label_at(Vector2(28, 38), "冷热搭子 · " + level_title, 28)
	label_at(Vector2(28, 70), "第 %d 关  |  种子 %d  |  宝石 %d/4  |  翻车 %d 次" % [stage, seed_number, collected, deaths])
	label_at(Vector2(28, 102), "模式：%s    [M] 切换模式    [TAB] 切换搭子    [R] 重开本关    [N] 新的冒险" % ("单人切换" if solo else "双人同屏"), 18)
	label_at(Vector2(28, 132), "单人：A/D 或方向键移动，W/↑/空格跳跃    双人：橙 A/D/W，蓝 ←/→/↑", 17)
	label_at(Vector2(28, 164), "① 各自踩一次同色踏板开门    ② 收齐同色宝石    ③ 一起走进各自的出口", 17)
	label_at(Vector2(28, 195), level_hint, 17)
	label_at(Vector2(28, 229), objective_status(), 18)
	for rect in platforms:
		draw_style_box(platform_style(), rect)
	for pool in pools:
		var color := buddy_color(pool.kind) if pool.kind < 2 else Color("9453bd")
		draw_rect(pool.rect, color)
		label_at(pool.rect.position + Vector2(4, 16), "~~~", 16, Color.WHITE)
	for device in devices:
		if device.type == "spring":
			draw_rect(Rect2(device.pos - Vector2(18, 10), Vector2(36,10)), Color("e2b83d"))
			label_at(device.pos + Vector2(-15,-18), "弹", 18)
		elif device.type == "bridge":
			draw_rect(Rect2(device.pos - Vector2(16, 8), Vector2(32,8)), buddy_color(device.kind))
			label_at(device.pos + Vector2(-15,-18), "桥" if not device.active else "好", 18)
		elif device.type == "wind":
			draw_rect(device.rect, Color(0.25,0.75,0.75,0.12))
			for line in 4:
				var point: Vector2 = device.rect.position + Vector2(30 + line * 22, 110)
				draw_line(point, point + Vector2(0,-60), Color("63b8bb"), 2)
				draw_line(point + Vector2(0,-60), point + Vector2(-5,-50), Color("63b8bb"), 2)
	for i in 2:
		draw_rect(Rect2(96 + i * 59, 603, 40, 7), buddy_color(i) if plates_activated[i] else buddy_color(i).darkened(0.5))
		label_at(Vector2(96 + i * 59, 639), "已踩" if plates_activated[i] else "踩我", 14)
		var exit_rect := Rect2(1020 + i * 60, 550, 40, 60)
		draw_style_box(exit_style(i), exit_rect)
		label_at(exit_rect.position + Vector2(9, 32), "开" if gate_open else "锁", 17, Color.WHITE)
	for gem in gems:
		if not gem.taken:
			var p: Vector2 = gem.pos
			draw_colored_polygon(PackedVector2Array([p + Vector2(0,-12), p + Vector2(10,0), p + Vector2(0,12), p + Vector2(-10,0)]), buddy_color(gem.kind))
	for i in 2:
		var p := buddies[i].position
		if solo and i == selected:
			draw_circle(p, 29, Color(1, 1, 1, 0.9))
		draw_style_box(character_style(i), Rect2(p - Vector2(15,21), Vector2(30,42)))
		for x in [-6, 6]:
			draw_circle(p + Vector2(x, -6), 4, Color.WHITE)
			draw_circle(p + Vector2(x + 1, -6), 2, Color("23354d"))
		draw_arc(p + Vector2(0, 3), 7, 0, PI, 12, Color("23354d"), 2)
	label_at(Vector2(28, 660), message, 20)
	label_at(Vector2(28, 696), "Demo 0.3 · Esc 暂停 · F1 帮助 · F11 全屏 · 自动保存关数", 16)
	if won:
		draw_rect(Rect2(210, 295, 730, 95), Color("23354d"))
		label_at(Vector2(270, 352), "搭子下班！下一关马上来……", 30, Color.WHITE)

func buddy_color(i: int) -> Color:
	return Color("f58b40") if i == 0 else Color("38aedd")

func platform_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LevelGenerator.THEMES[theme_index][2]
	style.border_width_top = 5
	style.border_color = LevelGenerator.THEMES[theme_index][3]
	return style

func character_style(i: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = buddy_color(i)
	style.set_corner_radius_all(10)
	return style

func exit_style(i: int) -> StyleBoxFlat:
	var style := character_style(i)
	if not gate_open:
		style.bg_color = style.bg_color.darkened(0.5)
	return style
