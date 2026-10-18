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

const DEFAULT_KEYS := {"orange_left":KEY_A,"orange_right":KEY_D,"orange_jump":KEY_W,"blue_left":KEY_LEFT,"blue_right":KEY_RIGHT,"blue_jump":KEY_UP}
const ACTION_LABELS := {"orange_left":"橙色左移","orange_right":"橙色右移","orange_jump":"橙色跳跃","blue_left":"蓝色左移","blue_right":"蓝色右移","blue_jump":"蓝色跳跃"}
const RESERVED := [KEY_ESCAPE,KEY_TAB,KEY_M,KEY_R,KEY_N,KEY_F1,KEY_F11,KEY_ENTER,KEY_KP_ENTER]

static func key_allowed(code: int, action: String) -> bool:
	if code in RESERVED:
		return false
	if code == KEY_SPACE:
		return action.ends_with("jump")
	return (code >= KEY_A and code <= KEY_Z) or (code >= KEY_0 and code <= KEY_9) or code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_SHIFT,KEY_CTRL,KEY_ALT]

static func valid_bindings(overrides: Dictionary) -> bool:
	var occupied: Array = []
	for action in overrides:
		if not DEFAULT_KEYS.has(action) or not overrides[action] is int:
			return false
	for action in DEFAULT_KEYS:
		var code: int = overrides.get(action,DEFAULT_KEYS[action])
		if not key_allowed(code,action) or code in occupied:
			return false
		occupied.append(code)
	return true

static func apply_bindings(overrides: Dictionary) -> void:
	if not valid_bindings(overrides):
		return
	var keys := DEFAULT_KEYS.duplicate()
	keys.merge(overrides,true)
	for action in keys:
		replace_keyboard(action,[keys[action]])
	for direction in ["left","right","jump"]:
		var codes: Array = [keys["orange_"+direction],keys["blue_"+direction]]
		if direction == "jump" and KEY_SPACE not in codes:
			codes.append(KEY_SPACE)
		replace_keyboard("solo_"+direction,codes)

static func replace_keyboard(action: String, codes: Array) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action,event)
	for code in codes:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(action,event)

static func key_name(code: int) -> String:
	return {KEY_LEFT:"←",KEY_RIGHT:"→",KEY_UP:"↑",KEY_DOWN:"↓",KEY_SPACE:"空格"}.get(code,OS.get_keycode_string(code))

static func legend(overrides: Dictionary) -> String:
	var keys := DEFAULT_KEYS.duplicate()
	keys.merge(overrides,true)
	return "橙色 %s/%s/%s · 蓝色 %s/%s/%s" % [key_name(keys.orange_left),key_name(keys.orange_right),key_name(keys.orange_jump),key_name(keys.blue_left),key_name(keys.blue_right),key_name(keys.blue_jump)]
