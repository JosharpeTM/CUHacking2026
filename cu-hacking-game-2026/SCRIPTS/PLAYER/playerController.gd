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

@export_category("Hover")
# The board rides on a hover cushion instead of resting on the ground: a ray
# probes straight down, and a damped spring holds the body HOVER_HEIGHT above
# whatever it finds. Raise hover_height to float higher; lower hover_damping for
# a floatier bob, raise it for a stiffer ride.
@export var hover_height: float = 2.0      # metres from the body origin down to the ground
@export var hover_stiffness: float = 6.0   # spring strength pulling back toward hover_height
@export var hover_damping: float = 40.0    # how fast vertical speed eases toward the spring target
# The ground is sampled at the board's centre and this far out toward each edge,
# so the nose/tail lift over ramps instead of clipping through. Set it near the
# board's half-length (≈ distance from centre to the tip).
@export var hover_probe_reach: float = 1.4

@export_category("Slope alignment")
# Tilt the board's visuals to match the ground beneath it, so it visibly pitches
# up going uphill (and rolls on banked ground). Purely cosmetic — the physics
# body and camera stay upright, so steering and the hover ride are unaffected.
@export var align_to_slope: bool = true
@export var align_smoothing: float = 8.0   # how fast the lean eases toward the slope — higher = snappier
@export var max_align_angle: float = 60.0  # clamp so a near-vertical face can't flip the board, but still covers steep ramps

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
const HOVER_IDLE_SPEED_SCALE: float = 1.0  # gentle hover jet while grounded
const HOVER_JUMP_SPEED_SCALE: float = 3.5  # jet flares faster while airborne
const HOVER_PROBE_EXTRA: float = 2.0   # keep sensing the ground this far below hover_height
const HOVER_GROUND_MARGIN: float = 0.5 # counts as "hovering" within this of the target height

# --- Internal state ---
var current_speed: float = 0.0     # signed forward speed (+forward / -backward)
var current_turn_rate: float = 0.0 # smoothed turning speed (radians/sec), eases toward target
var boost_amount: float = BOOST_START  # remaining boost fuel; read by the HUD
var _boosting: bool = false        # is boost being spent this frame?
var _grounded: bool = false        # riding the hover cushion (vs. airborne) — replaces is_on_floor
var _jump_active: bool = false     # true from a jump launch until the top of the arc (keeps hover off)
var _ground_normal: Vector3 = Vector3.UP  # surface normal under the board (from the hover ray)
var _hover_correction: float = 0.0 # eased vertical trim that holds the board at hover_height
var _tilt: Basis = Basis()         # current smoothed slope lean applied to the visuals
var _p: String = "p1_"             # input action prefix, built from player_id

# Trail particle nodes — they live in the scene so they can be repositioned in
# the editor. Boost trails fire while boosting; drive trails fire while rolling
# normally. Two of each, one per side of the board.
@onready var _boost_trails: Array[GPUParticles3D] = [$BoostTrail, $BoostTrail2]
@onready var _drive_trails: Array[GPUParticles3D] = [$DriveTrail, $DriveTrail2]
# Hover jet under the board: always on, drifting slowly, but flares faster while
# airborne (i.e. during a jump).
@onready var _hover_jet: GPUParticles3D = $HoverJet

# The child nodes that lean with the slope: the visuals AND the collision shapes.
# Tilting the colliders (not just the meshes) is what lets the board ride parallel
# to a steep ramp and clear it — the CharacterBody3D transform itself stays
# upright, so movement, steering and the camera rig are unaffected.
@onready var _tilt_nodes: Array[Node3D] = [
	$MeshInstance3D, $MeshInstance3D2,
	$CollisionShape3D, $CollisionShape3D2,
	$BoostTrail, $BoostTrail2, $DriveTrail, $DriveTrail2, $HoverJet,
]
var _tilt_rest: Array[Transform3D] = []  # each node's authored transform, captured at _ready

func _ready() -> void:
	_p = "p%d_" % player_id
	add_to_group("Player")
	# Remember where each node sits so the slope lean is applied relative to it.
	for n in _tilt_nodes:
		_tilt_rest.append(n.transform)


func _physics_process(delta: float) -> void:
	# During the "3 2 1 GO" countdown the skater is pinned at the start line:
	# ignore all input, kill any drift, but still settle onto the ground.
	if RaceManager.input_locked:
		current_speed = 0.0
		current_turn_rate = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		apply_hover(delta)  # still settle onto the hover cushion at the start line
		_update_slope_tilt(delta)
		move_and_slide()
		return

	handle_turning(delta)
	handle_boost(delta)
	handle_acceleration(delta)
	handle_jump(delta)
	apply_movement(delta)
	_update_slope_tilt(delta)  # align colliders to the ramp before resolving collisions
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
	var driving: bool = _grounded and absf(current_speed) > DRIVE_TRAIL_MIN_SPEED
	_set_emitting(_boost_trails, _boosting)
	_set_emitting(_drive_trails, driving and not _boosting)

	# Hover jet is always running; it just speeds up while in the air (a jump).
	if _hover_jet:
		_hover_jet.speed_scale = HOVER_JUMP_SPEED_SCALE if not _grounded else HOVER_IDLE_SPEED_SCALE


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
	if _grounded and Input.is_action_just_pressed(_p + "jump"):
		velocity.y = jump_velocity
		_jump_active = true  # keep the hover cushion off until we crest the jump


func apply_movement(delta: float) -> void:
	apply_hover(delta)

	# Forward direction is the skater's local -Z axis (Godot's forward), flat.
	var forward: Vector3 = -global_transform.basis.z

	if _grounded:
		# Drive ALONG the ground plane instead of flat: projecting the heading onto
		# the slope gives forward motion an up/down component that matches the ramp.
		# So climbing is powered by the drive itself — the board rises as it advances
		# instead of sinking and clipping its nose while the hover spring plays catch-up.
		var slope_dir: Vector3 = forward.slide(_ground_normal)
		slope_dir = slope_dir.normalized() if slope_dir.length() > 0.001 else forward
		var drive: Vector3 = slope_dir * current_speed
		velocity.x = drive.x
		velocity.z = drive.z
		velocity.y += drive.y  # climb/descend the ramp, on top of the hover-height trim
	else:
		# Airborne: no surface to follow, just carry the flat heading (air control).
		velocity.x = forward.x * current_speed
		velocity.z = forward.z * current_speed


## Hover ride: rather than resting on the floor, the board floats hover_height
## above whatever ground is beneath it. Several downward rays measure the gap
## across the board's footprint (see below). The vertical velocity is split in
## two: the *climb* to follow a ramp is handled by the slope-projected drive in
## apply_movement (feed-forward, no lag), and here we only compute _hover_correction
## — an eased trim that nudges the board back to hover_height. Setting velocity.y
## absolutely each frame (correction here, +drive.y in apply_movement) keeps the
## two from compounding. While rising fast (a fresh jump) the cushion yields and
## plain gravity takes over. Sets _grounded in place of is_on_floor().
func apply_hover(delta: float) -> void:
	var space_state := get_world_3d().direct_space_state
	var b: Basis = global_transform.basis
	var origin: Vector3 = global_position

	# Probe the ground at the board's centre and out near each edge, all cast
	# straight down. Sampling the footprint (not just the centre) is what keeps
	# the nose and tail from dipping into a ramp: we hover off whichever point is
	# closest to the ground, so the leading edge lifts as the slope rises.
	var probes := {
		"c": origin,
		"f": origin - b.z * hover_probe_reach,   # front (local -Z is forward)
		"r": origin + b.z * hover_probe_reach,   # rear
		"l": origin - b.x * hover_probe_reach,   # left
		"rt": origin + b.x * hover_probe_reach,  # right
	}
	var hit_pos := {}
	var nearest: float = INF  # smallest vertical gap under any probe = closest ground
	for key in probes:
		var from: Vector3 = probes[key]
		var to: Vector3 = from + Vector3.DOWN * (hover_height + HOVER_PROBE_EXTRA)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_rid()]  # ignore our own collision shapes
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty():
			hit_pos[key] = hit.position
			nearest = minf(nearest, from.y - hit.position.y)  # straight down, so this is the vertical gap

	# A jump is over once we've reached the top of the arc; from there the
	# within-reach test governs when the hover cushion catches us on the way down.
	if _jump_active and velocity.y <= 0.0:
		_jump_active = false

	# Airborne while a jump is still lifting us off, when there's nothing under the
	# board, or when the ground is too far below to ride — otherwise we're riding.
	# NB: climbing a ramp gives a big upward velocity too, but it stays *within
	# reach* of the ground, so it correctly counts as grounded (trails and all).
	var within_reach: bool = not hit_pos.is_empty() and nearest <= hover_height + HOVER_GROUND_MARGIN
	if _jump_active or not within_reach:
		_grounded = false
		_ground_normal = _ground_normal_from(hit_pos) if not hit_pos.is_empty() else Vector3.UP
		_hover_correction = 0.0
		velocity.y -= gravity * delta
		return

	# Riding: ease the height trim toward the spring target. The board's climb up a
	# ramp comes from the slope-projected drive (apply_movement), so this correction
	# only has to cancel residual error — it never has to power the whole ascent.
	_grounded = true
	_ground_normal = _ground_normal_from(hit_pos)  # steady lean, fit across the footprint
	var target_correction: float = (hover_height - nearest) * hover_stiffness
	_hover_correction = move_toward(_hover_correction, target_correction, hover_damping * delta)
	velocity.y = _hover_correction


## Surface normal fitted across the four edge probes — far steadier than a single
## triangle's face normal (which flickers between the map's collider triangles).
## Falls back to straight up until all four edge probes are on the ground.
func _ground_normal_from(hit_pos: Dictionary) -> Vector3:
	if hit_pos.has("f") and hit_pos.has("r") and hit_pos.has("l") and hit_pos.has("rt"):
		var forward_edge: Vector3 = hit_pos["f"] - hit_pos["r"]
		var right_edge: Vector3 = hit_pos["rt"] - hit_pos["l"]
		var n: Vector3 = right_edge.cross(forward_edge)  # points up for ground beneath us
		if n.y < 0.0:
			n = -n
		if n.length() > 0.0001:
			return n.normalized()
	return Vector3.UP


## Lean the board — visuals AND collision shapes — to match the ground, so it
## both looks like it's climbing the slope and physically rides parallel to it
## (which is what clears steep ramps). The CharacterBody3D transform stays upright,
## so movement, steering and the camera are untouched; we only rotate the child
## nodes around the origin so their "up" follows the ground normal. Airborne, it
## eases back to level.
func _update_slope_tilt(delta: float) -> void:
	var target := Basis()  # identity = level
	if align_to_slope:
		# Only lean to the ground while riding it; level out in the air.
		var world_up: Vector3 = _ground_normal if _grounded else Vector3.UP
		# Express the target "up" in the body's local frame so the lean reads as
		# pitch/roll relative to the way we're facing (the body only ever yaws).
		var local_up: Vector3 = (global_transform.basis.inverse() * world_up).normalized()
		# Clamp how far we'll lean so a near-vertical wall can't tip us over.
		var max_rad: float = deg_to_rad(max_align_angle)
		var angle: float = Vector3.UP.angle_to(local_up)
		if angle > max_rad and angle > 0.0001:
			local_up = Vector3.UP.slerp(local_up, max_rad / angle)
		# Shortest-arc rotation from straight-up to the (clamped) slope up: this is
		# pure pitch/roll with no yaw, so it never fights the steering.
		target = Basis(Quaternion(Vector3.UP, local_up))

	# Ease toward the target lean instead of snapping, so bumps don't jolt.
	var weight: float = 1.0 - exp(-align_smoothing * delta)
	_tilt = _tilt.slerp(target, weight)

	# Re-apply the lean on top of each node's authored transform, rotating it
	# about the body origin.
	var tilt_xform := Transform3D(_tilt, Vector3.ZERO)
	for i in _tilt_nodes.size():
		_tilt_nodes[i].transform = tilt_xform * _tilt_rest[i]
