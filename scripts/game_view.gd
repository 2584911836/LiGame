extends Node2D

const FONT: Font = preload("res://assets/ui-font.otf")
const LEVELS = preload("res://scripts/level_generator.gd")
const INK := Color("23354d")
var game: Node
var clock := 0.0
var particles: Array[Dictionary] = []
var effects_rng := RandomNumberGenerator.new()

func _ready() -> void:
	effects_rng.randomize()

func _process(delta: float) -> void:
	if game != null and game.screen == "play":
		clock += delta
		for p in particles:
			p.life -= delta
			p.pos += p.velocity * delta
			p.velocity.y += 450 * delta
		particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0)
	queue_redraw()

func burst(position: Vector2, color: Color, count: int = 10) -> void:
	if game.settings.reduced_motion:
		return
	for i in mini(count, 160 - particles.size()):
		particles.append({"pos": position, "velocity": Vector2(effects_rng.randf_range(-110,110), effects_rng.randf_range(-180,-40)), "life": effects_rng.randf_range(0.25,0.65), "color": color})

func text(position: Vector2, value: String, size: int = 18, color: Color = INK) -> void:
	draw_string(FONT, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color, radius: int = 10, outline: Color = Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if outline.a > 0:
		style.set_border_width_all(2)
		style.border_color = outline
	draw_style_box(style, rect)

func color_for(kind: int) -> Color:
	return Color("ef8843") if kind == 0 else Color("2b9fc7")

func symbol(kind: int, p: Vector2, size: float, color: Color) -> void:
	if kind == 0:
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-size),p+Vector2(size,size*0.7),p+Vector2(-size,size*0.7)]), color)
	elif kind == 1:
		draw_circle(p+Vector2(0, size*0.25), size*0.65, color)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-size),p+Vector2(size*0.6,size*0.1),p+Vector2(-size*0.6,size*0.1)]), color)
	else:
		draw_line(p-Vector2(size,size), p+Vector2(size,size), color, 2)
		draw_line(p+Vector2(size,-size), p+Vector2(-size,size), color, 2)

func _draw() -> void:
	if game == null:
		return
	var theme: Array = LEVELS.THEMES[game.theme_index]
	draw_rect(Rect2(0,0,1152,720), theme[1])
	draw_colored_polygon(PackedVector2Array([Vector2(0,470),Vector2(150,360),Vector2(335,465),Vector2(540,330),Vector2(790,470),Vector2(1010,350),Vector2(1152,450),Vector2(1152,610),Vector2(0,610)]), Color(0.2,0.5,0.6,0.06))
	for i in 6:
		var p := Vector2(i*220+30, 320+(i%2)*35)
		draw_arc(p, 34, 0, TAU, 32, Color(0.25,0.5,0.6,0.09), 6)
		draw_circle(p, 11, Color(0.25,0.5,0.6,0.06))
	# Compact HUD leaves the arena clear; detailed controls live in F1.
	draw_rect(Rect2(0,0,576,5), color_for(0))
	draw_rect(Rect2(576,0,576,5), color_for(1))
	text(Vector2(28,43), "冷热搭子", 27)
	text(Vector2(185,42), "第 %d 关 · %s" % [game.stage, game.level_title], 21)
	text(Vector2(805,41), "%s  |  种子 %06d" % ["单人切换" if game.solo else "双人同屏", game.seed_number], 17)
	panel(Rect2(24,62,1104,81), Color(1,1,1,0.88), 14)
	text(Vector2(42,91), "宝石  %d / 4" % game.collected, 20)
	text(Vector2(240,91), "翻车  %d 次" % game.deaths, 18)
	text(Vector2(420,91), "用时  %02d:%02d" % [int(game.elapsed)/60, int(game.elapsed)%60], 18)
	text(Vector2(735,91), "F1 帮助   Esc 暂停   Tab 换人", 17)
	text(Vector2(42,125), game.objective_status(), 17)
	text(Vector2(30,174), game.level_hint, 17)
	# Terrain and hazard silhouettes.
	for rect in game.platforms:
		if rect.position.y < 0 or rect.size.x < 40:
			continue
		panel(rect, theme[2], 5)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x,5)), theme[3])
		if rect.size.x < 200:
			for x in [12, int(rect.size.x)-12]:
				draw_circle(rect.position+Vector2(x,11), 2, Color(1,1,1,0.4))
	for pool in game.pools:
		var color: Color = color_for(pool.kind) if pool.kind < 2 else Color("9453bd")
		draw_rect(pool.rect, color)
		for x in range(12, int(pool.rect.size.x), 24):
			symbol(pool.kind, pool.rect.position+Vector2(x,8), 4, Color.WHITE)
	for device in game.devices:
		if device.type == "spring":
			var points := PackedVector2Array()
			for i in 7:
				points.append(device.pos+Vector2(-13 if i%2==0 else 13,-2-i*3))
			draw_polyline(points, Color("c19b24"), 3)
			panel(Rect2(device.pos-Vector2(19,23),Vector2(38,5)),Color("f4cf58"),2)
		elif device.type == "bridge":
			var tint := color_for(device.kind)
			panel(Rect2(device.pos-Vector2(17,10),Vector2(34,10)),tint,3)
			symbol(device.kind,device.pos-Vector2(0,22),7,tint)
			if not device.active:
				draw_rect(device.bridge,Color(tint,0.20),false,2)
				draw_line(device.pos-Vector2(0,4),device.bridge.get_center(),Color(tint,0.35),1)
		elif device.type == "wind":
			draw_rect(device.rect,Color(0.25,0.75,0.75,0.10))
			for i in 5:
				var shift: float = 0 if game.settings.reduced_motion else fmod(clock*32+i*29,140)
				var p: Vector2 = device.rect.position+Vector2(15+i*23,170-shift)
				draw_line(p,p+Vector2(0,-20),Color("63b8bb"),2)
				draw_line(p+Vector2(0,-20),p+Vector2(-4,-14),Color("63b8bb"),2)
	for i in 2:
		var tint := color_for(i)
		var plate := Rect2(96+i*59,602,40,8)
		panel(plate,tint if game.plates_activated[i] else tint.darkened(0.45),3)
		symbol(i,Vector2(116+i*59,622),5,tint.lightened(0.7))
		if game.plates_activated[i]:
			text(Vector2(103+i*59,643),"已踩",12,Color.WHITE)
		else:
			text(Vector2(103+i*59,643),"踩我",12,Color.WHITE)
		var gate := Rect2(1020+i*60,550,40,60)
		panel(gate, tint if game.gate_open else tint.darkened(0.50), 12)
		panel(Rect2(gate.position+Vector2(6,8),Vector2(28,52)),Color(0.1,0.2,0.25,0.25),8)
		symbol(i,gate.position+Vector2(20,18),7,Color.WHITE)
		text(gate.position+Vector2(12,45),"开" if game.gate_open else "锁",16,Color.WHITE)
	for gem in game.gems:
		if gem.taken:
			continue
		var p: Vector2 = gem.pos
		if not game.settings.reduced_motion:
			p.y += sin(clock*3+gem.pos.x)*3
		draw_circle(p,17,Color(color_for(gem.kind),0.10))
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-13),p+Vector2(11,0),p+Vector2(0,13),p+Vector2(-11,0)]),color_for(gem.kind))
		symbol(gem.kind,p,4,Color.WHITE)
	for i in 2:
		draw_buddy(i)
	for particle in particles:
		var tint: Color = particle.color
		tint.a = minf(1,particle.life*3)
		draw_circle(particle.pos,3,tint)
	panel(Rect2(24,654,1104,35),Color(1,1,1,0.88),9)
	text(Vector2(37,678),game.message,17)
	text(Vector2(29,709),"Demo 0.5 · F1 查看操作 · M 切换单双人 · R 重开 · N 新冒险 · F11 全屏",14)
	if game.won:
		panel(Rect2(225,265,702,120),INK,20)
		text(Vector2(300,313),"搭子下班！下一关马上来……",30,Color.WHITE)
		text(Vector2(345,353),"宝石收齐，工单清空，快乐摸鱼。",19,Color("c2ece0"))

func draw_buddy(i: int) -> void:
	var body: CharacterBody2D = game.buddies[i]
	var p := body.position
	var tint := color_for(i)
	var bob := 0.0
	if not game.settings.reduced_motion and body.is_on_floor() and absf(body.velocity.x)>1:
		bob = sin(clock*18)*2
	draw_ellipse_shadow(p+Vector2(0,22))
	if game.solo and i == game.selected:
		draw_arc(p,29,0,TAU,32,Color.WHITE,3)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-40),p+Vector2(5,-40),p+Vector2(0,-33)]),INK)
	panel(Rect2(p-Vector2(15,21-bob),Vector2(30,42)),tint,10)
	symbol(i,p+Vector2(0,-24+bob),7,tint)
	for eye_x in [-6,6]:
		draw_circle(p+Vector2(eye_x,-6+bob),4,Color.WHITE)
		draw_circle(p+Vector2(eye_x+1,-6+bob),2,INK)
	draw_arc(p+Vector2(0,3+bob),7,0,PI,12,INK,2)

func draw_ellipse_shadow(p: Vector2) -> void:
	draw_set_transform(p,0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,18,Color(0.05,0.15,0.2,0.12))
	draw_set_transform(Vector2.ZERO)
