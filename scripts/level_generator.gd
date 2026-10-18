extends RefCounted

const LESSONS := [
	["搭子入职", "先踩踏板开门，再跳上平台收同色宝石。失败不扣命，放心试！"],
	["弹簧加班", "黄色弹簧会自动弹起。松开跳跃键可缩短普通跳跃。"],
	["搭桥摸鱼", "踩亮桥前的同色开关，就能替搭子修一条安全路。"],
	["风里打卡", "青色风场减缓下落。先观察，再决定在哪里起跳。"],
	["离谱团建", "弹簧、桥梁和风场一起上场。配合比手速更重要。"],
	["下班考核", "最后一张工单！两位搭子都到出口，才算真正下班。"]
]
const THEMES := [
	["薄荷车间", Color("edf7fb"), Color("79b5a2"), Color("a8ddad")],
	["蜜桃仓库", Color("fff1e6"), Color("c38b87"), Color("f0bf94")],
	["星夜工厂", Color("e9e9fa"), Color("8f93be"), Color("c1c7ee")]
]

static func make(seed_id: int, stage: int, mode: String) -> Dictionary:
	var tutorial := mode == "lessons"
	var rng := RandomNumberGenerator.new()
	rng.seed = (2000 if tutorial else seed_id) + stage * 7919
	var data := {"platforms": [], "pools": [], "gems": [], "devices": [], "theme": (stage - 1) % 3, "title": "", "hint": ""}
	if tutorial:
		var lesson: Array = LESSONS[clampi(stage - 1, 0, LESSONS.size() - 1)]
		data.title = lesson[0]
		data.hint = lesson[1]
	else:
		data.title = "随机工单 %d" % stage
		data.hint = "同一种子可重玩相同地图。机关可绕过，宝石不可少。"
	for i in 4:
		var x := 230.0 + i * 205.0 + rng.randf_range(-12, 12)
		var y := rng.randf_range(475, 505)
		var kind := rng.randi_range(0, 2)
		if tutorial and stage == 1:
			y = 510
			kind = i % 2
		var pool := Rect2(x, 602, rng.randf_range(65, 90), 18)
		data.pools.append({"rect": pool, "kind": kind})
		data.platforms.append(Rect2(x - 8, y, 125, 18))
		data.gems.append({"pos": Vector2(x + 45, y - 28), "kind": i % 2, "taken": false})
		var device_kind := "none"
		if tutorial:
			if stage == 2:
				device_kind = "spring" if i % 2 == 0 else "none"
			elif stage == 3:
				device_kind = "bridge"
			elif stage == 4:
				device_kind = "wind"
			elif stage >= 5:
				device_kind = ["spring", "bridge", "wind", "bridge"][i]
		else:
			device_kind = ["spring", "bridge", "wind", "none"][rng.randi_range(0, 3)]
		if device_kind != "none":
			data.devices.append({"type": device_kind, "pos": Vector2(x - 38, 610), "rect": Rect2(x - 8, 415, 125, 195), "bridge": Rect2(x - 8, 594, pool.size.x + 16, 12), "kind": i % 2, "active": false, "cooldown": 0.0})
	return data
