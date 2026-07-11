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

var _split_time_left := 0.0
var _player: Node = null  # this HUD's skater, used to read the boost tank

@onready var split_label: Label = $SplitLabel
@onready var finished_label: Label = $FinishedLabel
@onready var boost_gauge = $BoostGauge


func _ready() -> void:
	split_label.visible = false
	finished_label.visible = false
	RaceManager.split_recorded.connect(_on_split_recorded)
	RaceManager.player_finished.connect(_on_player_finished)

	# Find the skater this HUD belongs to so we can mirror its boost tank.
	# Groups are tracked tree-wide, so this resolves even across SubViewports.
	for p in get_tree().get_nodes_in_group("Player"):
		if p.player_id == player_id:
			_player = p
			break


func _process(delta: float) -> void:
	if _split_time_left > 0.0:
		_split_time_left -= delta
		if _split_time_left <= 0.0:
			split_label.visible = false

	_update_boost()


## Feed the NOS gauge the skater's current boost fuel and whether it's firing.
func _update_boost() -> void:
	if not is_instance_valid(_player):
		return
	boost_gauge.set_boost(_player.boost_amount, _player.BOOST_MAX, _player.is_boosting())


func _on_split_recorded(pid: int, checkpoint_index: int, split_time: float) -> void:
	if pid != player_id:
		return
	split_label.text = "CP %d/%d  %s" % [checkpoint_index + 1, RaceManager.TOTAL_CHECKPOINTS, RaceManager.format_time(split_time)]
	split_label.visible = true
	_split_time_left = SPLIT_SHOW_TIME


func _on_player_finished(pid: int, final_time: float) -> void:
	if pid != player_id:
		return
	finished_label.text = "FINISHED  %s" % RaceManager.format_time(final_time)
	finished_label.visible = true
	split_label.visible = false
