extends SpringArm3D
 
## ---------------------------------------------------------
## CAMERA MOUSE + CONTROLLER LOOK (for the SpringArm3D chase camera)
## Lets the player look left/right up to a max angle with the
## mouse OR a gamepad right stick, independent of the skater's
## facing direction.
##
## Behaviors:
##  - Edge resistance: movement gets progressively less
##    effective as you approach the max angle, so it feels
##    like pushing against a soft limit instead of a hard wall.
##  - Auto-recenter: after a short pause with no look input,
##    the offset eases back to center on its own.
##  - Camera shake: call add_trauma() from your jump/land logic
##    to get a punchy screen shake that decays over time.
##
## Attach directly to the SpringArm3D node (the one that's a
## child of the skater, with Camera3D as its child).
##
## Input Map setup needed for the controller:
##   1. Project > Project Settings > Input Map
##   2. Add action "look_left"  -> bind to "Right Stick Left"  (Joypad Axis 2 -, or use the
##      "Manual Axis" picker and move the right stick left when prompted)
##   3. Add action "look_right" -> bind to "Right Stick Right" (Joypad Axis 2 +)
##   Godot's input popup detects stick direction automatically if you just move the
##   stick in that direction while it's listening for input.
## ---------------------------------------------------------
 
@export_category("Look Sensitivity")
@export var mouse_sensitivity: float = 0.005        # mouse relative motion -> radians
@export var controller_sensitivity: float = 3.0     # radians/sec at full stick deflection
@export var max_look_angle_degrees: float = 30.0    # clamp range, left and right
@export var edge_resistance_power: float = 2.0      # higher = resistance kicks in more sharply near the limit
 
@export_category("Auto Recenter")
@export var recenter_delay: float = 1.0    # seconds of no look input before recentering starts
@export var recenter_speed: float = 3.0    # higher = snaps back to center faster
 
@export_category("Camera Shake")
@export var shake_trauma_power: float = 1.0     # trauma is raised to this power before scaling shake (steeper falloff near 0)
@export var shake_decay: float = 1.4            # trauma units/sec removed
@export var shake_max_pitch_degrees: float = 4.0   # rotation.x jitter at full trauma
@export var shake_max_roll_degrees: float = 2.5    # rotation.z jitter at full trauma
@export var shake_max_offset: float = 2.0         # position jitter (meters) at full trauma
@export var shake_noise_speed: float = 25.0        # how fast the shake pattern evolves

@export_category("Speed FOV")
# Widen the camera's field of view as the skater speeds up, for a sense of rush
# at high speed. The FOV eases between base_fov (at a standstill) and
# base_fov + max_fov_boost (once speed reaches speed_for_max_fov). Boost/drift can
# push speed past max_speed, which keeps widening the FOV up to the cap.
@export var speed_fov_enabled: bool = true
@export var base_fov: float = 75.0          # FOV (degrees) when stopped; 0 = keep the camera's authored fov
@export var max_fov_boost: float = 20.0     # extra degrees added at speed_for_max_fov
@export var speed_for_max_fov: float = 35.0 # speed (m/s) at which the FOV boost is fully applied
@export var fov_smoothing: float = 5.0      # how fast the FOV eases toward its target — higher = snappier
@export var boost_fov_punch: float = 14.0   # extra FOV degrees while boost is firing — a sharp kick on top of the speed FOV

@export_category("Speed Feel")
# Third-person speed is sold by the CAMERA, not the car: as you speed up the rig
# pulls back and drops lower so the ground/world rushes past, tilts down a touch to
# fill the frame with oncoming track, and buzzes with a high-frequency rumble. All
# of it scales with speed and eases in/out. Turn any piece to 0 to disable it.
@export var speed_feel_enabled: bool = true
@export var pullback_distance: float = 1.0    # metres the arm extends at top speed (world streams past)
@export var camera_drop: float = 0.45         # metres the camera lowers at top speed (low angle = fast)
@export var speed_pitch_degrees: float = 3.0  # downward tilt at top speed, so more track fills the frame
@export var speed_rumble: float = 0.06        # metres of high-frequency camera jitter at top speed
@export var speed_rumble_frequency: float = 55.0  # how fast that jitter vibrates — higher = tenser shimmer
@export var speed_feel_smoothing: float = 3.5     # how fast the dolly/drop/pitch ease in and out with speed

var look_yaw: float = 0.0        # current look offset, in radians
var base_rotation_y: float = 0.0 # the SpringArm3D's original authored rotation (e.g. facing behind the skater)
var base_rotation_x: float = 0.0 # captured so external/inherited rotation can't creep onto the arm
var base_rotation_z: float = 0.0
var base_position: Vector3 = Vector3.ZERO
var idle_time: float = 0.0       # time since look input was last received
var _p: String = "p1_"           # input action prefix, taken from the parent skater's player_id
 
var _trauma: float = 0.0
var _shake_noise: FastNoiseLite

var _speed01: float = 0.0            # eased 0..1 speed factor driving all the speed-feel cues
var _base_spring_length: float = 0.0 # the arm's authored length, extended with speed
var _rest_position: Vector3 = Vector3.ZERO  # base_position + speed drop/rumble; shake jitters around this

@onready var _camera: Camera3D = $Camera3D  # child camera whose FOV we drive with speed


func _ready() -> void:
	base_rotation_y = rotation.y
	base_rotation_x = rotation.x
	base_rotation_z = rotation.z
	base_position = position
	_rest_position = position
	_base_spring_length = spring_length
	_p = "p%d_" % get_parent().player_id

	# Fall back to the camera's authored FOV as the resting FOV when base_fov is 0,
	# so the effect layers on top of whatever the scene was set up with.
	if _camera and base_fov <= 0.0:
		base_fov = _camera.fov

	_shake_noise = FastNoiseLite.new()
	_shake_noise.seed = randi()
	_shake_noise.frequency = 1.0
 
 
func _process(delta: float) -> void:
	# Controller right-stick look. get_axis returns 0 when no controller is connected
	# or the stick is centered, so this is safe to leave running.
	var stick_input: float = Input.get_axis(_p + "look_left", _p + "look_right")
	if abs(stick_input) > 0.0:
		_apply_look_delta(-stick_input * controller_sensitivity * delta)
 
	idle_time += delta
 
	# After a pause with no look input, ease the offset back to center.
	if idle_time >= recenter_delay and look_yaw != 0.0:
		var weight: float = 1.0 - exp(-recenter_speed * delta)
		look_yaw = lerp(look_yaw, 0.0, weight)
 
	# Speed feel first — it computes _speed01, the arm dolly, the resting position,
	# and the FOV, all of which the rotation/shake below build on.
	_update_speed_feel(delta)

	# Own X/Z rotation explicitly every frame. If something else (a jump squash/stretch
	# tween, a lean animation on the skater root, etc.) rotates a parent of this node,
	# this stops that rotation from leaking into the arm and swinging the camera up.
	# The speed pitch tips the nose down a touch at speed so more track fills the frame.
	rotation.x = base_rotation_x - deg_to_rad(speed_pitch_degrees) * _speed01
	rotation.z = base_rotation_z
	rotation.y = base_rotation_y + look_yaw

	_update_shake(delta)


## The heart of the "feel faster" system. In third person the car barely moves on
## screen, so speed has to come from the camera: as the skater speeds up we widen
## the FOV (with an extra kick while boosting), extend the spring arm so the world
## rushes past, drop the rig lower for a fast low angle, and add a high-frequency
## rumble. Everything scales with an eased speed factor so it swells and settles
## smoothly instead of snapping. Reads the parent skater's current_speed/max_speed.
func _update_speed_feel(delta: float) -> void:
	var skater = get_parent()
	var speed: float = absf(skater.current_speed)
	var max_speed: float = skater.max_speed

	# Eased 0..1 speed factor shared by every cue below.
	var raw01: float = clamp(speed / max_speed, 0.0, 1.0) if max_speed > 0.0 else 0.0
	var weight: float = 1.0 - exp(-speed_feel_smoothing * delta)
	_speed01 = lerp(_speed01, raw01, weight)

	# --- FOV (speed widen + boost punch) ---
	if speed_fov_enabled and _camera:
		var fov_ratio: float = clamp(speed / speed_for_max_fov, 0.0, 1.0) if speed_for_max_fov > 0.0 else 0.0
		var target_fov: float = base_fov + max_fov_boost * fov_ratio
		if skater.is_boosting():
			target_fov += boost_fov_punch
		var fov_weight: float = 1.0 - exp(-fov_smoothing * delta)
		_camera.fov = lerp(_camera.fov, target_fov, fov_weight)

	if not speed_feel_enabled:
		_rest_position = base_position
		spring_length = _base_spring_length
		return

	# --- Dolly the arm back and drop the rig as speed builds ---
	spring_length = _base_spring_length + pullback_distance * _speed01
	var rest: Vector3 = base_position + Vector3(0.0, -camera_drop * _speed01, 0.0)

	# --- High-frequency rumble at speed (organic, from noise so it doesn't loop) ---
	if speed_rumble > 0.0 and _speed01 > 0.001:
		var t: float = Time.get_ticks_msec() / 1000.0 * speed_rumble_frequency
		var rx: float = _shake_noise.get_noise_2d(t, 500.0)
		var ry: float = _shake_noise.get_noise_2d(t, 900.0)
		rest += Vector3(rx, ry, 0.0) * speed_rumble * _speed01

	_rest_position = rest

 
## Applies a raw yaw delta (from mouse or controller) with edge resistance and clamping,
## and resets the auto-recenter idle timer. Shared by both input sources so they behave
## identically near the limit.
func _apply_look_delta(raw_delta: float) -> void:
	idle_time = 0.0
	var max_rad: float = deg_to_rad(max_look_angle_degrees)
	var delta_yaw: float = raw_delta
 
	# If this movement is pushing further toward the edge (same direction the camera
	# is already looking), scale it down the closer we are to the limit. Movement back
	# toward center is never resisted.
	var moving_away_from_center: bool = look_yaw == 0.0 or sign(delta_yaw) == sign(look_yaw)
	if moving_away_from_center:
		var proximity: float = clamp(abs(look_yaw) / max_rad, 0.0, 1.0)
		var resistance: float = pow(1.0 - proximity, edge_resistance_power)
		delta_yaw *= resistance
 
	look_yaw = clamp(look_yaw + delta_yaw, -max_rad, max_rad)
 
 
## Call from mouse motion handling, e.g. in _unhandled_input:
##   if event is InputEventMouseMotion:
##       _apply_look_delta(-event.relative.x * mouse_sensitivity)
## (kept as a separate public entry point if you want to call it from _unhandled_input)
func apply_mouse_delta(relative_x: float) -> void:
	_apply_look_delta(-relative_x * mouse_sensitivity)
 
 
## ---------------------------------------------------------
## CAMERA SHAKE
## Trauma-based shake (Squirrel Eiserloh's GDC model): trauma is a 0-1 value
## that decays linearly over time. Actual shake magnitude is trauma raised to
## a power, so small bumps barely shake but big hits (like a hard landing)
## really punch. Call add_trauma() from your skater script:
##
##   $SpringArm3D.add_trauma(0.3)   # jump takeoff
##   $SpringArm3D.add_trauma(0.6)   # landing (scale with fall speed if you like)
## ---------------------------------------------------------
 
func add_trauma(amount: float) -> void:
	_trauma = clamp(_trauma + amount, 0.0, 1.0)
 
 
func _update_shake(delta: float) -> void:
	# Trauma shake jitters around _rest_position (which already carries the speed
	# drop + rumble), so the two systems layer instead of fighting over position.
	_trauma = max(_trauma - shake_decay * delta, 0.0)
	var shake: float = pow(_trauma, shake_trauma_power)

	if shake <= 0.0001:
		position = _rest_position
		return

	var t: float = Time.get_ticks_msec() / 1000.0 * shake_noise_speed
	# Sample noise at offset coordinates per axis so they don't move in lockstep.
	var n_pitch: float = _shake_noise.get_noise_2d(t, 0.0)
	var n_roll: float = _shake_noise.get_noise_2d(t, 100.0)
	var n_x: float = _shake_noise.get_noise_2d(t, 200.0)
	var n_y: float = _shake_noise.get_noise_2d(t, 300.0)

	rotation.x += deg_to_rad(shake_max_pitch_degrees) * shake * n_pitch
	rotation.z += deg_to_rad(shake_max_roll_degrees) * shake * n_roll
	position = _rest_position + Vector3(
		shake_max_offset * shake * n_x,
		shake_max_offset * shake * n_y,
		0.0
	)
