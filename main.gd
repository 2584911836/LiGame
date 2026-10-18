extends Node2D

const FLOOR_Y := 610.0
const SPEED := 245.0
const JUMP := -720.0
const GRAVITY := 1450.0
const QUIPS := ["搭子齐心，其利断金——也可能一起掉进汤里。", "温馨提示：岩浆不是免费温泉。", "本队仅有两个脑细胞，请轮流使用。", "请勿把你的搭子放进微波炉。"]
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

func _ready() -> void:
	seed_number = int(Time.get_unix_time_from_system()) % 1000000
	for i in 2:
		var body := CharacterBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(30, 42)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		buddies.append(body)
	generate()

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
	rng.seed = seed_number + stage * 7919
	add_platform(Rect2(0, FLOOR_Y, 1152, 110))
	add_platform(Rect2(-30, 0, 30, 720))
	add_platform(Rect2(1152, 0, 30, 720))
	# Bounded gaps and heights guarantee a traversable ground route.
	for i in 4:
		var x := 230.0 + i * 205.0 + rng.randf_range(-18, 18)
		var width := rng.randf_range(65, 95)
		pools.append({"rect": Rect2(x, FLOOR_Y - 8, width, 18), "kind": rng.randi_range(0, 2)})
		var y := rng.randf_range(465, 505)
		add_platform(Rect2(x - 8, y, 125, 18))
		gems.append({"pos": Vector2(x + 45, y - 28), "kind": i % 2, "taken": false})
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
		buddies[i].velocity = Vector2.ZERO

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_TAB:
			selected = 1 - selected
		KEY_M:
			solo = not solo
		KEY_R:
			generate()
		KEY_N:
			seed_number = (seed_number + 104729) % 1000000
			stage = 1
			generate()

func _physics_process(delta: float) -> void:
	if won:
		transition += delta
		if transition > 1.8:
			stage += 1
			generate()
		queue_redraw()
		return
	for i in 2:
		var body := buddies[i]
		var horizontal := 0.0
		var jump := false
		if solo:
			if i == selected:
				horizontal = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
				jump = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE)
		else:
			var left := KEY_A if i == 0 else KEY_LEFT
			var right := KEY_D if i == 0 else KEY_RIGHT
			var up := KEY_W if i == 0 else KEY_UP
			horizontal = float(Input.is_physical_key_pressed(right)) - float(Input.is_physical_key_pressed(left))
			jump = Input.is_physical_key_pressed(up)
		body.velocity.x = horizontal * SPEED
		body.velocity.y += GRAVITY * delta
		if body.is_on_floor() and jump:
			body.velocity.y = JUMP
		body.move_and_slide()
		for pool in pools:
			if pool.rect.has_point(body.position + Vector2(0, 20)) and pool.kind != i:
				deaths += 1
				message = "喝错汤了！搭子一起重生，宝石和门锁进度保留。"
				reset_buddies()
				queue_redraw()
				return
		for gem in gems:
			if not gem.taken and gem.kind == i and body.position.distance_to(gem.pos) < 34:
				gem.taken = true
				collected += 1
	update_objectives()
	queue_redraw()

func update_objectives() -> void:
	# Each matching plate latches separately so solo players can activate them in any order.
	for i in 2:
		if Rect2(96 + i * 59, 565, 40, 45).has_point(buddies[i].position):
			plates_activated[i] = true
	gate_open = plates_activated[0] and plates_activated[1]
	if gate_open and collected == gems.size() and at_exit(0) and at_exit(1):
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
	draw_rect(Rect2(0, 0, 1152, 720), Color("edf7fb"))
	for i in 8:
		draw_circle(Vector2(i * 180 + 40, 280 + (i % 3) * 50), 90, Color("e1eef3"))
	label_at(Vector2(28, 38), "冷热搭子 · 摸鱼闯关队", 28)
	label_at(Vector2(28, 70), "第 %d 关  |  种子 %d  |  宝石 %d/4  |  翻车 %d 次" % [stage, seed_number, collected, deaths])
	label_at(Vector2(28, 102), "模式：%s    [M] 切换模式    [TAB] 切换搭子    [R] 重开本关    [N] 新的冒险" % ("单人切换" if solo else "双人同屏"), 18)
	label_at(Vector2(28, 132), "单人：A/D 或方向键移动，W/↑/空格跳跃    双人：橙 A/D/W，蓝 ←/→/↑", 17)
	label_at(Vector2(28, 164), "① 各自踩一次同色踏板开门    ② 收齐同色宝石    ③ 一起走进各自的出口", 17)
	label_at(Vector2(28, 195), "橙色不怕橙色池，蓝色不怕蓝色池；紫色毒汤谁喝谁重来。踏板在出生点右侧。", 17)
	label_at(Vector2(28, 229), objective_status(), 18)
	for rect in platforms:
		draw_style_box(platform_style(), rect)
	for pool in pools:
		var color := buddy_color(pool.kind) if pool.kind < 2 else Color("9453bd")
		draw_rect(pool.rect, color)
		label_at(pool.rect.position + Vector2(4, 16), "~~~", 16, Color.WHITE)
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
	label_at(Vector2(28, 696), "Demo 0.1.1 · 随机关卡 · 无限重试 · 原创几何画风 · 无联网需求", 16)
	if won:
		draw_rect(Rect2(210, 295, 730, 95), Color("23354d"))
		label_at(Vector2(270, 352), "搭子下班！下一关马上来……", 30, Color.WHITE)

func buddy_color(i: int) -> Color:
	return Color("f58b40") if i == 0 else Color("38aedd")

func platform_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("79b5a2")
	style.border_width_top = 5
	style.border_color = Color("a8ddad")
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
