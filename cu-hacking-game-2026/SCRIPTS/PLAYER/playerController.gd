extends CharacterBody3D

## ---------------------------------------------------------
## SKATER PLAYER CONTROLLER
## Handles: accelerating, braking, turning, and jumping.
## Attach to a CharacterBody3D with a CollisionShape3D and
## a visual mesh (skater model) as children.
## ---------------------------------------------------------

# --- Movement tuning ---
@export_category("Speed")
@export var max_speed: float = 12.0          # top speed (m/s)
@export var acceleration_speed: float = 6.0  # how fast the skater speeds up
@export var brake_speed: float = 14.0        # how fast the skater slows down when braking
@export var friction: float = 2.0            # natural deceleration when idle (rolling resistance)

@export_category("Turning")
@export var turn_speed: float = 2.5          # radians/sec at full speed
@export var min_turn_speed: float = 0.4      # radians/sec when standing still (lets you pivot a bit)
@export var turn_smoothing: float = 4.0      # how quickly turning eases in/out — LOWER = floatier, HIGHER = snappier

@export_category("Jumping")
@export var jump_velocity: float = 11.0
@export var gravity: float = 20.0

# --- Internal state ---
var current_speed: float = 0.0     # signed forward speed (+forward / -backward)
var current_turn_rate: float = 0.0 # smoothed turning speed (radians/sec), eases toward target

func _physics_process(delta: float) -> void:
	handle_turning(delta)
	handle_acceleration(delta)
	handle_jump(delta)
	apply_movement(delta)
	move_and_slide()


func handle_turning(delta: float) -> void:
	var turn_input := Input.get_axis("turn_left", "turn_right")

	# Turning is more responsive at speed, but still possible while nearly stopped.
	var speed_factor: float = clamp(abs(current_speed) / max_speed, 0.0, 1.0)
	var effective_turn_speed: float = lerp(min_turn_speed, turn_speed, speed_factor)

	# Reverse the turn direction when skating backwards, like a real vehicle/board.
	var direction_sign: float = sign(current_speed) if current_speed != 0.0 else 1.0

	var target_turn_rate: float = turn_input * effective_turn_speed * direction_sign

	# Ease current_turn_rate toward the target instead of snapping to it. This is what
	# gives turning a "floaty" feel — the skater winds up into a turn and coasts out of
	# it when you release the key, rather than starting/stopping instantly.
	var turn_weight: float = 1.0 - exp(-turn_smoothing * delta)
	current_turn_rate = lerp(current_turn_rate, target_turn_rate, turn_weight)

	rotate_y(-current_turn_rate * delta)


func handle_acceleration(delta: float) -> void:
	var accelerate: bool = Input.is_action_pressed("accelerate")
	var brake: bool = Input.is_action_pressed("brake")

	if accelerate and not brake:
		current_speed += acceleration_speed * delta
	elif brake and not accelerate:
		# Braking works whether moving forward or backward, always pushing toward 0
		# (or into reverse if held while stopped).
		if current_speed > 0.0:
			current_speed -= brake_speed * delta
			current_speed = max(current_speed, 0.0)
		else:
			current_speed -= acceleration_speed * delta
	else:
		# No input: gradually slow down due to friction/rolling resistance.
		if current_speed > 0.0:
			current_speed = max(current_speed - friction * delta, 0.0)
		elif current_speed < 0.0:
			current_speed = min(current_speed + friction * delta, 0.0)

	current_speed = clamp(current_speed, -max_speed * 0.5, max_speed)  # reverse capped slower


func handle_jump(_delta: float) -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity


func apply_movement(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Forward direction is the skater's local -Z axis (Godot's forward).
	var forward: Vector3 = -global_transform.basis.z
	var horizontal_velocity: Vector3 = forward * current_speed

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
