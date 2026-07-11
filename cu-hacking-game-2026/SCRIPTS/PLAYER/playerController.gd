extends CharacterBody3D

## ---------------------------------------------------------
## SKATER PLAYER CONTROLLER
## Handles: accelerating, braking, turning, and jumping.
## Attach to a CharacterBody3D with a CollisionShape3D and
## a visual mesh (skater model) as children.
## ---------------------------------------------------------

# --- Player identity ---
# 1 or 2: selects which input actions drive this skater (p1_* / p2_*)
# and which controller (device 0 / device 1) it listens to.
@export_range(1, 2) var player_id: int = 1

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

@export_category("Boost")
# Rocket-League-style boost: a fuel tank (0..BOOST_MAX) you spend by HOLDING
# R1. It doesn't regenerate on its own — you top it up by driving over boost
# pads scattered around the track.
@export var boost_speed_bonus: float = 8.0   # extra top speed while boosting
@export var boost_accel: float = 16.0        # forward thrust applied while boosting
@export var boost_drain_rate: float = 33.0   # tank units spent per second of boost

const BOOST_MAX: float = 100.0
const BOOST_START: float = 50.0  # racers launch with a half tank
const DRIVE_TRAIL_MIN_SPEED: float = 1.0  # min speed before the drive trails kick in

# --- Internal state ---
var current_speed: float = 0.0     # signed forward speed (+forward / -backward)
var current_turn_rate: float = 0.0 # smoothed turning speed (radians/sec), eases toward target
var boost_amount: float = BOOST_START  # remaining boost fuel; read by the HUD
var _boosting: bool = false        # is boost being spent this frame?
var _p: String = "p1_"             # input action prefix, built from player_id

# Trail particle nodes — they live in the scene so they can be repositioned in
# the editor. Boost trails fire while boosting; drive trails fire while rolling
# normally. Two of each, one per side of the board.
@onready var _boost_trails: Array[GPUParticles3D] = [$BoostTrail, $BoostTrail2]
@onready var _drive_trails: Array[GPUParticles3D] = [$DriveTrail, $DriveTrail2]

func _ready() -> void:
	_p = "p%d_" % player_id
	add_to_group("Player")


func _physics_process(delta: float) -> void:
	# During the "3 2 1 GO" countdown the skater is pinned at the start line:
	# ignore all input, kill any drift, but still settle onto the ground.
	if RaceManager.input_locked:
		current_speed = 0.0
		current_turn_rate = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	handle_turning(delta)
	handle_boost(delta)
	handle_acceleration(delta)
	handle_jump(delta)
	apply_movement(delta)
	move_and_slide()
	_update_trails()


## R1 boost: hold R1 to spend boost fuel for extra thrust and a raised top
## speed. Drains the tank while held; does nothing once it's empty. The actual
## speed effect is applied in handle_acceleration via the _boosting flag.
func handle_boost(delta: float) -> void:
	_boosting = Input.is_action_pressed(_p + "boost") and boost_amount > 0.0
	if _boosting:
		boost_amount = maxf(boost_amount - boost_drain_rate * delta, 0.0)


## Drive the trail particles: boost streaks while boosting, and the softer
## drive streaks while rolling along the ground (but not while boosting, so the
## boost trail cleanly takes over). Called after move_and_slide so is_on_floor
## and current_speed are up to date.
func _update_trails() -> void:
	var driving: bool = is_on_floor() and absf(current_speed) > DRIVE_TRAIL_MIN_SPEED
	_set_emitting(_boost_trails, _boosting)
	_set_emitting(_drive_trails, driving and not _boosting)


func _set_emitting(trails: Array, on: bool) -> void:
	for t in trails:
		if t:
			t.emitting = on


## Whether the skater is actively spending boost this frame (read by the HUD
## gauge so it can glow while boosting).
func is_boosting() -> bool:
	return _boosting


## Refill the boost tank (called by boost pads). Returns how much was actually
## added, so a pad can leave itself untouched when the racer is already full.
func add_boost(amount: float) -> float:
	var before: float = boost_amount
	boost_amount = clampf(boost_amount + amount, 0.0, BOOST_MAX)
	return boost_amount - before


func handle_turning(delta: float) -> void:
	var turn_input := Input.get_axis(_p + "turn_left", _p + "turn_right")

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
	var accelerate: bool = Input.is_action_pressed(_p + "accelerate")
	var brake: bool = Input.is_action_pressed(_p + "brake")

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

	# While boosting, add thrust and lift the top-speed cap so the surge sticks.
	var top_speed: float = max_speed
	if _boosting:
		current_speed += boost_accel * delta
		top_speed = max_speed + boost_speed_bonus

	current_speed = clamp(current_speed, -max_speed * 0.5, top_speed)  # reverse capped slower


func handle_jump(_delta: float) -> void:
	if is_on_floor() and Input.is_action_just_pressed(_p + "jump"):
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
