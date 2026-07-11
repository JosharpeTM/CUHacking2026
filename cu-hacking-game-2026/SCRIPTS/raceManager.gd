extends Node

## ---------------------------------------------------------
## RACE MANAGER (autoload singleton)
## Owns all race state: per-player timers, checkpoint splits,
## finish times. Survives scene changes, so the results screen
## can read the final times after the race scene is gone.
## ---------------------------------------------------------

signal split_recorded(player_id: int, checkpoint_index: int, split_time: float)
signal player_finished(player_id: int, final_time: float)

const TOTAL_CHECKPOINTS := 3
const MENU_SCENE := "res://TSCN/UI/main_menu.tscn"
const RACE_SCENE := "res://TSCN/MAP/race.tscn"
const RESULTS_SCENE := "res://TSCN/UI/results.tscn"

var race_active := false
var race_elapsed := 0.0  # shared race clock, runs until BOTH players finish
var players := {}  # player_id -> {elapsed, splits: Array, next_cp, finished, final_time}


## Reset all race state and start the clocks. Called by race.gd when
## the race scene loads (so "Play Again" resets everything for free).
func start_race() -> void:
	players = {}
	for pid in [1, 2]:
		players[pid] = {
			"elapsed": 0.0,
			"splits": [],
			"next_cp": 0,
			"finished": false,
			"final_time": 0.0,
		}
	race_elapsed = 0.0
	race_active = true


func _process(delta: float) -> void:
	if not race_active:
		return
	race_elapsed += delta
	for pid in players:
		if not players[pid].finished:
			players[pid].elapsed += delta


## Called by a checkpoint gate. Only counts if it's this player's next
## expected checkpoint — re-entering a gate or hitting them out of
## order does nothing (and plays no sound).
func checkpoint_passed(player_id: int, checkpoint_index: int) -> bool:
	if not race_active or not players.has(player_id):
		return false
	var p: Dictionary = players[player_id]
	if p.finished or checkpoint_index != p.next_cp:
		return false
	p.splits.append(p.elapsed)
	p.next_cp += 1
	split_recorded.emit(player_id, checkpoint_index, p.elapsed)
	return true


## Called by the finish line. Only counts once per player, and only
## after all checkpoints have been passed. When BOTH players are done,
## switch to the results scene.
func player_finished_at_line(player_id: int) -> bool:
	if not race_active or not players.has(player_id):
		return false
	var p: Dictionary = players[player_id]
	if p.finished or p.next_cp < TOTAL_CHECKPOINTS:
		return false
	p.finished = true
	p.final_time = p.elapsed
	player_finished.emit(player_id, p.final_time)

	var all_done := true
	for pid in players:
		if not players[pid].finished:
			all_done = false
	if all_done:
		race_active = false
		get_tree().change_scene_to_file.call_deferred(RESULTS_SCENE)
	return true


## Current display time: frozen at final_time once the player finishes.
func get_time(player_id: int) -> float:
	if not players.has(player_id):
		return 0.0
	var p: Dictionary = players[player_id]
	return p.final_time if p.finished else p.elapsed


static func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	var millis := int(fmod(t, 1.0) * 1000.0)
	return "%02d:%02d.%03d" % [minutes, int(seconds), millis]
