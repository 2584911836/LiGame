class_name Buddy
extends CharacterBody2D

const SPEED := 245.0
const JUMP := -720.0
const GRAVITY := 1450.0
const COYOTE_TIME := 0.10
const BUFFER_TIME := 0.12
var coyote := 0.0
var jump_buffer := 0.0
var jump_was_held := false
var jumped := false

func _init() -> void:
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(30, 42)
	collider.shape = box
	add_child(collider)
	# Buddies can pass each other; solo mode must never trap the inactive buddy.
	collision_layer = 2
	collision_mask = 1

func reset_motion() -> void:
	velocity = Vector2.ZERO
	coyote = 0
	jump_buffer = 0
	jump_was_held = false

func step(delta: float, axis: float, jump_held: bool) -> void:
	jumped = false
	jump_buffer = maxf(0, jump_buffer - delta)
	coyote = COYOTE_TIME if is_on_floor() else maxf(0, coyote - delta)
	if jump_held and not jump_was_held:
		jump_buffer = BUFFER_TIME
	velocity.x = axis * SPEED
	velocity.y = minf(1000, velocity.y + GRAVITY * delta)
	if jump_buffer > 0 and coyote > 0:
		velocity.y = JUMP
		jump_buffer = 0
		coyote = 0
		jumped = true
	if not jump_held and jump_was_held and velocity.y < -300:
		velocity.y = -300
	jump_was_held = jump_held
	move_and_slide()
