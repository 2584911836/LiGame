extends RefCounted

static func setup() -> void:
	bind("orange_left", [KEY_A], 0, JOY_AXIS_LEFT_X, -1, JOY_BUTTON_DPAD_LEFT)
	bind("orange_right", [KEY_D], 0, JOY_AXIS_LEFT_X, 1, JOY_BUTTON_DPAD_RIGHT)
	bind("orange_jump", [KEY_W], 0, -1, 0, JOY_BUTTON_A)
	bind("blue_left", [KEY_LEFT], 1, JOY_AXIS_LEFT_X, -1, JOY_BUTTON_DPAD_LEFT)
	bind("blue_right", [KEY_RIGHT], 1, JOY_AXIS_LEFT_X, 1, JOY_BUTTON_DPAD_RIGHT)
	bind("blue_jump", [KEY_UP], 1, -1, 0, JOY_BUTTON_A)
	bind("solo_left", [KEY_A, KEY_LEFT], 0, JOY_AXIS_LEFT_X, -1, JOY_BUTTON_DPAD_LEFT)
	bind("solo_right", [KEY_D, KEY_RIGHT], 0, JOY_AXIS_LEFT_X, 1, JOY_BUTTON_DPAD_RIGHT)
	bind("solo_jump", [KEY_W, KEY_UP, KEY_SPACE], 0, -1, 0, JOY_BUTTON_A)
	bind("switch_buddy", [KEY_TAB], 0, -1, 0, JOY_BUTTON_X)

static func bind(action: String, keys: Array, device: int, axis: int, axis_value: float, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	var joy := InputEventJoypadButton.new()
	joy.device = device
	joy.button_index = button
	InputMap.action_add_event(action, joy)
	if axis >= 0:
		var stick := InputEventJoypadMotion.new()
		stick.device = device
		stick.axis = axis
		stick.axis_value = axis_value
		InputMap.action_add_event(action, stick)

static func read(solo: bool, selected: int, buddy_id: int) -> Vector2:
	if solo and selected != buddy_id:
		return Vector2.ZERO
	var prefix := "solo" if solo else ("orange" if buddy_id == 0 else "blue")
	return Vector2(Input.get_axis(prefix + "_left", prefix + "_right"), 1 if Input.is_action_pressed(prefix + "_jump") else 0)
