extends CharacterBody3D

## ---------------------------------------------------------
## SKATER PLAYER CONTROLLER
## Handles: accelerating, braking, turning, jumping, and drifting.
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
@export var turn_speed: float = 0.7        # radians/sec at full speed
@export var min_turn_speed: float = 0.4      # radians/sec when standing still (lets you pivot a bit)
@export var turn_smoothing: float = 8.0      # how quickly turning eases in/out — LOWER = floatier, HIGHER = snappier

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

@export_category("Drift")
# Hold the "drift" action while turning to break grip: instead of your velocity
# snapping to face direction every frame, it eases toward it (see drift_grip_rate),
# so the board slides sideways through the turn. Keep steering into the slide to
# build charge; release (or run out of speed / leave the ground) to cash it in as
# a speed kick — bigger the longer you held it. Needs an input action:
#   Project > Project Settings > Input Map > add action "drift" -> bind to a
#   shoulder button (L1/LB) or Shift, using the "p%d_drift" prefix convention
#   (i.e. "p1_drift" / "p2_drift") like the other actions in this script.
@export var drift_min_speed: float = 20.0           # minimum |speed| needed to start (or keep) a drift
@export var drift_turn_multiplier: float = 2.5     # extra turn rate while drifting, so the slide actually carves
@export var drift_grip_rate: float = 3.5           # how fast velocity direction catches up to facing while drifting — LOWER = more slide, HIGHER = snappier
@export var drift_charge_rate: float = 1.0         # charge/sec built while actively steering into the drift
@export var drift_tier1_charge: float = 0.5        # seconds held to reach tier 1
@export var drift_tier2_charge: float = 1.1        # tier 2
@export var drift_tier3_charge: float = 1.9        # tier 3 — the big one
@export var drift_tier1_kick: float = 2.5          # instant speed granted at tier 1
@export var drift_tier2_kick: float = 4.5          # tier 2
@export var drift_tier3_kick: float = 7.5          # tier 3
@export var drift_boost_duration: float = 0.7      # seconds the top-speed cap is raised after a boost, so friction/clamping doesn't eat the kick immediately
@export var drift_speed_penalty: float = 5.0       # extra deceleration (m/s^2) applied to current_speed while drifting — stops you from just holding the drift button forever
@export var drift_max_speed: float = 35.0

@export_category("Character Motion")
# Cosmetic life for the skater mesh: a vertical BOB and a side-to-side SWAY while
# driving (both scale with speed and only play while grounded), plus a hard lean
# TILT into a powerslide. Purely visual — layered onto the character mesh on top
# of the slope tilt, so it never touches the physics body, steering or camera.
@export var bob_amplitude: float = 0.07        # metres of vertical bounce at full speed
@export var bob_frequency: float = 11.0        # base bob rate (further scaled by speed)
@export var sway_angle: float = 4.0            # degrees of side-to-side roll while driving
@export var drift_tilt_angle: float = 20.0     # degrees the skater leans into a drift
@export var turn_lean_angle: float = 6.0       # degrees the skater leans into a normal (non-drift) turn — a subtle version of the drift lean
@export var character_lean_smoothing: float = 9.0  # how fast the drift/turn lean eases in/out

@export_category("Wall Impact")
# When move_and_slide hits something roughly wall-shaped (near-horizontal
# collision normal — steep/vertical normals are the ground/ramp, already
# handled by the hover system), a hard enough hit chops your speed and
# punches the camera. Scales with impact speed like the landing shake does.
@export var wall_impact_min_speed: float = 3.0     # below this impact speed, no penalty at all
@export var wall_impact_max_speed: float = 14.0    # at/above this impact speed, full penalty + full trauma
@export var wall_impact_speed_retained: float = 0.15  # fraction of current_speed kept after a full-strength hit (0 = dead stop)
@export var wall_impact_max_trauma: float = 0.8

@export_category("Camera Shake")
# How much trauma (0..1) to feed the camera rig's shake on jump takeoff, and
# the range used to scale landing shake by impact speed (fast fall = big hit).
@export var jump_trauma: float = 0.2
@export var min_landing_impact_speed: float = 2.0   # below this, landing gives ~no shake
@export var max_landing_impact_speed: float = 18.0  # at/above this, landing gives full trauma
@export var max_landing_trauma: float = 0.85
@export var drift_tier1_trauma: float = 0.25        # camera punch on a tier-1 drift release
@export var drift_tier2_trauma: float = 0.5         # tier 2
@export var drift_tier3_trauma: float = 0.9         # tier 3

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

# --- Drift state ---
var _drifting: bool = false        # currently holding a powerslide
var _drift_side: float = 1.0       # which way the slide was initiated (+1 right, -1 left); charging requires steering this way
var _drift_charge: float = 0.0     # seconds spent actively steering into the current drift
var _move_dir: Vector3 = Vector3.FORWARD  # actual horizontal movement direction — decoupled from facing while drifting
var _drift_boost_bonus: float = 0.0  # extra top-speed cap left over from a drift boost
var _drift_boost_timer: float = 0.0  # seconds remaining on that raised cap

# --- Character motion state (cosmetic) ---
var _bob_phase: float = 0.0        # advancing phase driving the bob/sway oscillation
var _character_lean: float = 0.0   # smoothed roll (radians) for the drift tilt

var crash_cooldown: float = 0.0

# Trail particle nodes — they live in the scene so they can be repositioned in
# the editor. Boost trails fire while boosting; drive trails fire while rolling
# normally. Two of each, one per side of the board.
@onready var _boost_trails: Array[GPUParticles3D] = [$BoostTrail, $BoostTrail2]
@onready var _drive_trails: Array[GPUParticles3D] = [$DriveTrail, $DriveTrail2]
# Hover jet under the board: always on, drifting slowly, but flares faster while
# airborne (i.e. during a jump).
@onready var _hover_jet: GPUParticles3D = $HoverJet
# Camera rig (SpringArm3D, see camera_look.gd) — used to trigger shake on jump
# takeoff and landing. Adjust the path if your camera rig lives somewhere else.
@onready var _camera_rig: SpringArm3D = $SpringArm3D

@onready var _crash_sound: AudioStreamPlayer = $AudioStreamPlayer3
# The child nodes that lean with the slope: the visuals AND the collision shapes.
# Tilting the colliders (not just the meshes) is what lets the board ride parallel
# to a steep ramp and clear it — the CharacterBody3D transform itself stays
# upright, so movement, steering and the camera rig are unaffected.
@onready var _tilt_nodes: Array[Node3D] = [
	$dxracer_goyim,$CollisionShape3D,$BoostTrail, $BoostTrail2, $DriveTrail, $DriveTrail2, $HoverJet,
]
var _tilt_rest: Array[Transform3D] = []  # each node's authored transform, captured at _ready

# The skater body that gets the bob/sway/drift-tilt life on top of the slope lean.
@onready var _character_mesh = $dxracer_goyim
var _character_rest: Transform3D = Transform3D()  # its authored transform, captured at _ready

func _ready() -> void:
	_p = "p%d_" % player_id
	add_to_group("Player")
	# Seed the respawn point (Triangle/Y) with the start spawn until the first
	# checkpoint is cleared. Runs before the race scene root calls start_race().
	RaceManager.set_respawn(player_id, global_transform)
	_move_dir = -global_transform.basis.z
	# Remember where each node sits so the slope lean is applied relative to it.
	for n in _tilt_nodes:
		_tilt_rest.append(n.transform)
	_character_rest = _character_mesh.transform


func _physics_process(delta: float) -> void:
	# Triangle/Y: warp back to the last checkpoint (or spawn). Only while the
	# race is live — during the countdown you're already parked at the line.
	if RaceManager.race_active and Input.is_action_just_pressed(_p + "respawn"):
		_respawn_to_checkpoint()
		return

	# During the "3 2 1 GO" countdown the skater is pinned at the start line:
	# ignore all input, kill any drift, but still settle onto the ground.
	if RaceManager.input_locked:
		current_speed = 0.0
		current_turn_rate = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		_drifting = false
		_drift_charge = 0.0
		apply_hover(delta)  # still settle onto the hover cushion at the start line
		_update_slope_tilt(delta)
		_update_character_motion(delta)  # eases the bob/lean back to rest while pinned
		move_and_slide()
		return

	handle_drift(delta)  # before turning, since it changes the turn rate this frame
	handle_turning(delta)
	handle_boost(delta)
	handle_acceleration(delta)
	handle_jump(delta)
	handle_kickflip()
	apply_movement(delta)
	_update_slope_tilt(delta)  # align colliders to the ramp before resolving collisions
	_update_character_motion(delta)  # bob/sway/drift-tilt on the skater mesh, over the slope lean
	var velocity_before_slide: Vector3 = velocity  # captured pre-collision, to measure impact speed
	move_and_slide()
	_handle_wall_impacts(velocity_before_slide)
	handle_collision(delta)
	_update_trails()


## Warp the skater back to their last cleared checkpoint (Triangle/Y), facing
## the way they were driving through it. Kills all momentum and any in-progress
## drift/boost so they get a clean, stationary restart — mirrors the fall-off-map
## reset the race scenes already do.
func _respawn_to_checkpoint() -> void:
	global_transform = RaceManager.get_respawn(player_id)
	velocity = Vector3.ZERO
	current_speed = 0.0
	current_turn_rate = 0.0
	_drifting = false
	_drift_charge = 0.0
	_drift_boost_bonus = 0.0
	_drift_boost_timer = 0.0
	_move_dir = -global_transform.basis.z


## Powerslide: hold "drift" while steering to break grip and start a slide.
## Keep steering into the slide to build charge through three tiers; letting go
## of the button, dropping below drift_min_speed, or leaving the ground ends the
## drift and cashes in whatever tier was reached as an instant speed kick.
func handle_drift(delta: float) -> void:
	var drift_held: bool = Input.is_action_pressed(_p + "drift")
	var turn_input: float = Input.get_axis(_p + "turn_left", _p + "turn_right")
	var can_drift: bool = _grounded and absf(current_speed) > drift_min_speed

	if not _drifting and drift_held and can_drift and absf(turn_input) > 0.1:
		_drifting = true
		_drift_charge = 0.0
		_drift_side = sign(turn_input)
	elif _drifting and (not drift_held or not can_drift):
		_release_drift()

	if _drifting:
		# Only charge while steering into the side the slide was locked to (or
		# neutral). A hard counter-steer lets you fight the slide for control,
		# but it stops the charge from climbing.
		if turn_input == 0.0 or sign(turn_input) == _drift_side:
			_drift_charge += drift_charge_rate * delta


func _release_drift() -> void:
	if _drift_charge >= drift_tier3_charge:
		_apply_drift_boost(drift_tier3_kick, drift_tier3_trauma)
	elif _drift_charge >= drift_tier2_charge:
		_apply_drift_boost(drift_tier2_kick, drift_tier2_trauma)
	elif _drift_charge >= drift_tier1_charge:
		_apply_drift_boost(drift_tier1_kick, drift_tier1_trauma)
	_drifting = false
	_drift_charge = 0.0


## Grants an instant speed kick and temporarily raises the top-speed cap
## (drift_boost_duration) so handle_acceleration's clamp doesn't immediately
## erase it. Also punches the camera — bigger tier, bigger punch.
func _apply_drift_boost(kick: float, trauma: float) -> void:
	current_speed += kick
	_drift_boost_bonus = max(_drift_boost_bonus, kick)
	_drift_boost_timer = drift_boost_duration
	if _camera_rig:
		_camera_rig.add_trauma(trauma)


## Whether the skater is mid-powerslide (read by the HUD to show a charge meter,
## or by trail/particle logic to switch to spark colors per tier).
func is_drifting() -> bool:
	return _drifting


## Current drift tier (0 = not charged past tier 1 yet, 1-3 = tier reached).
## Useful for coloring drift sparks blue/orange/purple like the tuning implies.
func get_drift_tier() -> int:
	if _drift_charge >= drift_tier3_charge:
		return 3
	elif _drift_charge >= drift_tier2_charge:
		return 2
	elif _drift_charge >= drift_tier1_charge:
		return 1
	return 0


## R1 boost: hold R1 to spend boost fuel for extra thrust and a raised top
## speed. Drains the tank while held; does nothing once it's empty. The actual
## speed effect is applied in handle_acceleration via the _boosting flag.
func handle_boost(delta: float) -> void:
	_boosting = Input.is_action_pressed(_p + "boost") and boost_amount > 0.0
	if _boosting:
		boost_amount = maxf(boost_amount - boost_drain_rate * delta, 0.0)
		if !$AudioStreamPlayer2.playing:
			$AudioStreamPlayer2.play()
		else:
			if $AudioStreamPlayer2.playing:
				$AudioStreamPlayer2.stop()

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


## Checks the collisions move_and_slide just resolved for a hard wall hit.
## Ground/ramp contact is filtered out by normal — the hover system keeps the
## body from ever really touching the ground, so a near-horizontal normal
## reliably means a wall or prop. On a hard enough hit, current_speed is
## slashed (scaled by how fast we were driving into it) and the current drift
## is cancelled with no payout. Next frame's apply_movement rebuilds velocity
## from the reduced current_speed, so nothing here needs to touch velocity
## directly.
func _handle_wall_impacts(pre_velocity: Vector3) -> void:
	var strongest_impact: float = 0.0
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal: Vector3 = collision.get_normal()
		if absf(normal.y) > 0.6:
			continue  # steep/vertical normal = ground or ramp, not a wall
		var into_wall: float = -pre_velocity.dot(normal)  # how fast we were driving into the surface
		strongest_impact = max(strongest_impact, into_wall)

	if strongest_impact < wall_impact_min_speed:
		return

	var t: float = clamp(
		(strongest_impact - wall_impact_min_speed) / (wall_impact_max_speed - wall_impact_min_speed),
		0.0, 1.0
	)
	var retained: float = lerp(1.0, wall_impact_speed_retained, t)
	current_speed *= retained

	# A hard hit blows the drift with no reward — no free charge for smacking a wall.
	_drifting = false
	_drift_charge = 0.0
	_drift_boost_bonus = 0.0
	_drift_boost_timer = 0.0

	if _camera_rig:
		_camera_rig.add_trauma(lerp(0.0, wall_impact_max_trauma, t))


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

	# Drifting carves harder than a normal turn — this is what makes a powerslide
	# actually change your heading instead of just sliding you in a straight line.
	if _drifting:
		effective_turn_speed *= drift_turn_multiplier

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
	
	if absf(current_speed) > 0.1:
		if !$AudioStreamPlayer.playing:
			$AudioStreamPlayer.play()
	
		# Increase pitch with speed, lower pitch when slowing down
		var speed_ratio: float = absf(current_speed) / max_speed
		$AudioStreamPlayer.pitch_scale = lerp(0.6, 2.0, speed_ratio)

	else:
		if $AudioStreamPlayer.playing:
			$AudioStreamPlayer.stop()
		
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

	# A drift boost temporarily raises the cap too, so the kick from
	# _apply_drift_boost isn't immediately clamped back down. Ticks down here.
	if _drift_boost_timer > 0.0:
		_drift_boost_timer = max(_drift_boost_timer - delta, 0.0)
		top_speed = max(top_speed, max_speed + _drift_boost_bonus)
		if _drift_boost_timer == 0.0:
			_drift_boost_bonus = 0.0

	# Drifting bleeds speed steadily — you can't just hold the button forever
	# for free grip-loss; you have to actually cash it in. handle_drift already
	# ends the drift on its own once this drops you below drift_min_speed.
	if _drifting:
		current_speed -= drift_speed_penalty * delta
		current_speed = min(current_speed, drift_max_speed)

	current_speed = clamp(current_speed, -max_speed * 0.5, top_speed)  # reverse capped slower


func handle_jump(_delta: float) -> void:
	if _grounded and Input.is_action_just_pressed(_p + "jump"):
		velocity.y = jump_velocity
		_jump_active = true  # keep the hover cushion off until we crest the jump
		# Play jump sound
		$AudioStreamPlayer4.play()
		if _camera_rig:
			_camera_rig.add_trauma(jump_trauma)


## X button (or the X key for P1): trigger a one-shot kickflip on the skater
## mesh. Purely cosmetic — it doesn't touch movement, so you can pull it off
## mid-drive. The mesh handles playing the clip and easing back into the drive
## loop; this just forwards the press.
func handle_kickflip() -> void:
	if Input.is_action_just_pressed(_p + "kickflip"):
		_character_mesh.kickflip()


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

		if _drifting:
			# Grip loosens: _move_dir eases toward the facing direction instead of
			# snapping to it, so the board slides sideways through the turn rather
			# than carving it cleanly. Lower drift_grip_rate = more slide.
			var weight: float = 1.0 - exp(-drift_grip_rate * delta)
			_move_dir = _move_dir.slerp(slope_dir, weight)
		else:
			_move_dir = slope_dir

		var drive: Vector3 = _move_dir * current_speed
		velocity.x = drive.x
		velocity.z = drive.z
		velocity.y += drive.y  # climb/descend the ramp, on top of the hover-height trim
	else:
		# Airborne: no surface to follow, just carry the flat heading (air control).
		_move_dir = forward
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
## plain gravity takes over. Sets _grounded in place of is_on_floor(), and fires
## a landing shake on the frame we transition from airborne to grounded.
func apply_hover(delta: float) -> void:
	var was_grounded: bool = _grounded
	var incoming_velocity_y: float = velocity.y  # captured before hover/gravity touch it this frame

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

	# We just landed this frame (airborne -> grounded): shake the camera, scaled
	# by how hard we hit. incoming_velocity_y is negative while falling, so a
	# bigger fall gives a bigger (positive) impact speed.
	if not was_grounded and _camera_rig:
		var impact_speed: float = max(-incoming_velocity_y, 0.0)
		if impact_speed > min_landing_impact_speed:
			var t: float = clamp(
				(impact_speed - min_landing_impact_speed) / (max_landing_impact_speed - min_landing_impact_speed),
				0.0, 1.0
			)
			_camera_rig.add_trauma(lerp(0.0, max_landing_trauma, t))


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


## Cosmetic life for the skater mesh, layered on top of the slope tilt (which has
## already reset the mesh's transform this frame, so this override wins):
##  - BOB: a vertical bounce that speeds up and grows with velocity, only while
##    grounded (an airborne board floats steadily).
##  - SWAY: a slower side-to-side roll off the same phase, so the body rocks as
##    it rolls along.
##  - TILT: a hard lean into a powerslide, easing in when the drift starts and
##    back out when it ends.
## None of this touches the physics body, steering, hover or camera — it only
## re-poses the character mesh about the body origin.
func _update_character_motion(delta: float) -> void:
	var speed_factor: float = clamp(absf(current_speed) / max_speed, 0.0, 1.0)
	var drive_factor: float = speed_factor if _grounded else 0.0

	# Advance the bob phase faster the quicker we're going; keep a small idle rate
	# so it never fully freezes while coasting.
	_bob_phase += bob_frequency * (0.4 + speed_factor) * delta
	var bob: float = sin(_bob_phase) * bob_amplitude * drive_factor
	# Sway rolls at half the bob rate for a natural rocking cadence.
	var sway: float = sin(_bob_phase * 0.5) * deg_to_rad(sway_angle) * drive_factor

	# Lean into the turn. A full drift leans hard into the slide (_drift_side is
	# +1 right / -1 left); a normal turn gets a much gentler lean driven by how hard
	# we're actually turning (current_turn_rate), scaled by speed so it only shows
	# while moving. Both feed the same eased _character_lean, so easing out of a drift
	# blends straight into the normal-turn lean instead of snapping to level.
	var target_lean: float
	if _drifting:
		target_lean = -_drift_side * deg_to_rad(drift_tilt_angle)
	else:
		var turn_ratio: float = clamp(current_turn_rate / turn_speed, -1.0, 1.0)
		target_lean = -turn_ratio * deg_to_rad(turn_lean_angle) * drive_factor
	var weight: float = 1.0 - exp(-character_lean_smoothing * delta)
	_character_lean = lerp(_character_lean, target_lean, weight)

	# Roll about the forward (local Z) axis for the sway + drift lean, and bob up
	# along local Y. Layer under the slope tilt so it reads relative to the ground.
	var roll := Basis(Vector3(0.0, 0.0, 1.0), _character_lean + sway)
	var anim_xform := Transform3D(roll, Vector3(0.0, bob, 0.0))
	var tilt_xform := Transform3D(_tilt, Vector3.ZERO)
	_character_mesh.transform = tilt_xform * anim_xform * _character_rest

func handle_collision(delta: float) -> void:
	crash_cooldown -= delta
	
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()

		# Only trigger on walls, not the ground
		if abs(normal.y) < 0.5 and current_speed > 5:
			if crash_cooldown <= 0.0:
				$AudioStreamPlayer3.play()
				crash_cooldown = 2.0 # seconds between crashes
			break
