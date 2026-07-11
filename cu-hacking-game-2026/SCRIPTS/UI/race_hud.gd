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

@onready var split_label: Label = $SplitLabel
@onready var finished_label: Label = $FinishedLabel


func _ready() -> void:
	split_label.visible = false
	finished_label.visible = false
	RaceManager.split_recorded.connect(_on_split_recorded)
	RaceManager.player_finished.connect(_on_player_finished)


func _process(delta: float) -> void:
	if _split_time_left > 0.0:
		_split_time_left -= delta
		if _split_time_left <= 0.0:
			split_label.visible = false


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
