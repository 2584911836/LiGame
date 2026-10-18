extends CanvasLayer

signal chosen(action: String)
const FONT = preload("res://assets/ui-font.otf")
var cover: ColorRect
var box: VBoxContainer

func _ready() -> void:
	cover = ColorRect.new()
	cover.color = Color(0.06, 0.12, 0.20, 1.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(center)
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(660, 0)
	box.add_theme_constant_override("separation", 12)
	box.add_theme_font_override("font", FONT)
	center.add_child(box)

func show_screen(title: String, description: String, buttons: Array) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	box.add_child(heading)
	var body := Label.new()
	body.text = description
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 19)
	box.add_child(body)
	var first: Button
	for data in buttons:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size", 20)
		var action: String = data[1]
		button.pressed.connect(func() -> void: chosen.emit(action))
		box.add_child(button)
		if first == null:
			first = button
	visible = true
	if first:
		first.grab_focus()

func seed_entry() -> void:
	show_screen("指定工单种子", "输入 0 到 999999 的数字，重玩或分享同一张随机地图。", [["开始挑战", "start_seed"], ["返回标题", "title"]])
	var field := LineEdit.new()
	field.name = "SeedInput"
	field.placeholder_text = "例如：12345"
	field.max_length = 6
	field.custom_minimum_size.y = 44
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size",24)
	box.add_child(field)
	box.move_child(field,2)
	field.text_submitted.connect(func(_value: String) -> void: chosen.emit("start_seed"))
	field.grab_focus()
	var error := Label.new()
	error.name = "SeedError"
	error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error.add_theme_color_override("font_color",Color("ffc5a0"))
	box.add_child(error)

func read_seed() -> int:
	var field := box.get_node("SeedInput") as LineEdit
	var value := field.text.strip_edges()
	if not value.is_valid_int() or int(value) < 0 or int(value) > 999999:
		box.get_node("SeedError").text = "请输入 0 到 999999 的数字。"
		return -1
	return int(value)
