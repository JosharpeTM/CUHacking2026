extends Control

## ---------------------------------------------------------
## PER-PLAYER RACE HUD
## Lives inside that player's SubViewport, so it only shows
## on their half of the screen. Flashes checkpoint splits and
## a FINISHED banner. (The race timer itself is shared and
## drawn once in the middle of the screen by race.gd.)
## ---------------------------------------------------------

@export_range(1, 2) var player_id: int = 1

const SPLIT_SHOW_TIME := 2.0

# Speed lines: as a fraction of the skater's max_speed, where the streaks begin to
# show and where they hit full intensity. The full point is > 1.0 on purpose so the
# lines only max out when boosting/drifting past normal top speed.
const SPEED_LINES_START_RATIO := 0.55
const SPEED_LINES_FULL_RATIO := 1.4
const SPEED_LINES_SMOOTHING := 6.0  # how fast intensity eases toward its target

var _split_time_left := 0.0
var _player: Node = null  # this HUD's skater, used to read the boost tank
var _speed_lines_intensity := 0.0  # eased 0..1 driving the speed-lines shader

@onready var split_label: Label = $SplitLabel
@onready var finished_label: Label = $FinishedLabel
@onready var lap_label: Label = $LapLabel
@onready var boost_gauge = $BoostGauge
@onready var speed_lines: ColorRect = $SpeedLines
@onready var motion_blur: ColorRect = $MotionBlur


func _ready() -> void:
	split_label.visible = false
	finished_label.visible = false
	_update_lap_label(1)
	RaceManager.split_recorded.connect(_on_split_recorded)
	RaceManager.player_finished.connect(_on_player_finished)
	RaceManager.lap_completed.connect(_on_lap_completed)

	# Find the skater this HUD belongs to so we can mirror its boost tank.
	_resolve_player()


## Locate this HUD's skater by player_id from the tree-wide "Player" group.
## Groups resolve even across SubViewports. This can miss on the first try if the
## HUD readies before the skater has added itself to the group (scene-order
## dependent — e.g. time trial lists the HUD before the track), so _process()
## retries until it resolves.
func _resolve_player() -> void:
	for p in get_tree().get_nodes_in_group("Player"):
		if p.player_id == player_id:
			_player = p
			return


func _process(delta: float) -> void:
	# Keep trying to bind the skater until it exists in the group — it may ready
	# after this HUD depending on scene node order.
	if not is_instance_valid(_player):
		_resolve_player()

	if _split_time_left > 0.0:
		_split_time_left -= delta
		if _split_time_left <= 0.0:
			split_label.visible = false

	_update_boost()
	_update_speed_effects(delta)


## Feed the NOS gauge the skater's current boost fuel and whether it's firing.
func _update_boost() -> void:
	if not is_instance_valid(_player):
		return
	boost_gauge.set_boost(_player.boost_amount, _player.BOOST_MAX, _player.is_boosting())


## Ramp the speed overlays (radial speed lines + radial motion blur) with the
## skater's speed: nothing until it's moving briskly, building to full once it
## blows past top speed on a boost/drift. Eased so pops of speed fade in and out
## smoothly, and the same factor drives both effects so they read as one.
func _update_speed_effects(delta: float) -> void:
	var target := 0.0
	if is_instance_valid(_player):
		var speed: float = absf(_player.current_speed)
		var start: float = _player.max_speed * SPEED_LINES_START_RATIO
		var full: float = _player.max_speed * SPEED_LINES_FULL_RATIO
		if full > start:
			target = clampf((speed - start) / (full - start), 0.0, 1.0)

	var weight: float = 1.0 - exp(-SPEED_LINES_SMOOTHING * delta)
	_speed_lines_intensity = lerp(_speed_lines_intensity, target, weight)
	speed_lines.material.set_shader_parameter("intensity", _speed_lines_intensity)
	# Motion blur rides the same speed factor, eased slightly (squared) so it stays
	# subtle at mid speed and only really smears near the top end.
	motion_blur.material.set_shader_parameter("strength", _speed_lines_intensity * _speed_lines_intensity)


func _on_split_recorded(pid: int, checkpoint_index: int, split_time: float) -> void:
	if pid != player_id:
		return
	split_label.text = "CP %d/%d  %s" % [checkpoint_index + 1, RaceManager.total_checkpoints, RaceManager.format_time(split_time)]
	split_label.visible = true
	_split_time_left = SPLIT_SHOW_TIME


func _on_lap_completed(pid: int, new_lap: int, _total_laps: int) -> void:
	if pid != player_id:
		return
	_update_lap_label(new_lap)


func _update_lap_label(lap: int) -> void:
	lap_label.text = "LAP %d/%d" % [lap, RaceManager.TOTAL_LAPS]


func _on_player_finished(pid: int, final_time: float) -> void:
	if pid != player_id:
		return
	finished_label.text = "FINISHED  %s" % RaceManager.format_time(final_time)
	finished_label.visible = true
	split_label.visible = false
