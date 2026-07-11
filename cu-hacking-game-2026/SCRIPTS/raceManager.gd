extends Node

## ---------------------------------------------------------
## RACE MANAGER (autoload singleton)
## Owns all race state: per-player timers, checkpoint splits,
## finish times. Survives scene changes, so the results screen
## can read the final times after the race scene is gone.
## ---------------------------------------------------------

signal split_recorded(player_id: int, checkpoint_index: int, split_time: float)
signal player_finished(player_id: int, final_time: float)
# Emitted each second of the pre-race countdown. value counts 3 -> 2 -> 1,
# then 0 to signal "GO!". The HUD listens to animate the 3-2-1-GO overlay.
signal countdown_tick(value: int)

const TOTAL_CHECKPOINTS := 3
# How many seconds the "3 2 1 GO" countdown runs before the racers are freed.
const COUNTDOWN_SECONDS := 3
const MENU_SCENE := "res://TSCN/UI/main_menu.tscn"
const RACE_SCENE := "res://TSCN/MAP/race.tscn"
const TIME_TRIAL_SCENE := "res://TSCN/MAP/time_trial.tscn"
const RESULTS_SCENE := "res://TSCN/UI/results.tscn"

# Where the best time-trial time is persisted between sessions.
const SCORE_PATH := "user://scores.cfg"

var race_active := false
var input_locked := false  # true during the countdown: skaters can't move yet
var race_elapsed := 0.0  # shared race clock, runs until every racer finishes
var players := {}  # player_id -> {elapsed, splits: Array, next_cp, finished, final_time}

# Mode + time-trial result state, read by the results screen.
var is_time_trial := false
var previous_best := 0.0   # best time BEFORE this run (0.0 == no record yet)
var is_new_record := false # did the run just set a new best?


func _ready() -> void:
	# The game is controller-only, and Godot only delivers joypad input to the
	# window that currently holds OS input focus. On launch (and in fullscreen)
	# the window can come up unfocused, so the controller appears dead until you
	# click the window. Grab focus up front — and again whenever we regain it —
	# so controllers work without needing a mouse click.
	_grab_window_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_grab_window_focus()


func _grab_window_focus() -> void:
	DisplayServer.window_move_to_foreground()
	var win := get_window()
	if win:
		win.grab_focus()


## Reset all race state and start the clocks. Called by the race scene
## when it loads (so "Play Again" resets everything for free).
## Pass time_trial=true for the single-player (Player 1 only) mode.
func start_race(time_trial := false) -> void:
	is_time_trial = time_trial
	is_new_record = false
	previous_best = 0.0
	var ids: Array = [1] if time_trial else [1, 2]
	players = {}
	for pid in ids:
		players[pid] = {
			"elapsed": 0.0,
			"splits": [],
			"next_cp": 0,
			"finished": false,
			"final_time": 0.0,
		}
	race_elapsed = 0.0
	# Hold the racers at the line and keep the clock frozen until the
	# "3 2 1 GO" countdown finishes.
	race_active = false
	input_locked = true
	_run_countdown()


## Run the pre-race countdown, then free the racers. Emits countdown_tick
## once a second (3, 2, 1) and finally 0 for "GO!", at which point the clock
## starts and input unlocks.
func _run_countdown() -> void:
	for n in range(COUNTDOWN_SECONDS, 0, -1):
		countdown_tick.emit(n)
		await get_tree().create_timer(1.0).timeout
		# Bail out if the race was torn down mid-countdown (scene change).
		if not input_locked:
			return
	countdown_tick.emit(0)  # GO!
	input_locked = false
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
		if is_time_trial:
			_finalize_time_trial()
		get_tree().change_scene_to_file.call_deferred(RESULTS_SCENE)
	return true


## Current display time: frozen at final_time once the player finishes.
func get_time(player_id: int) -> float:
	if not players.has(player_id):
		return 0.0
	var p: Dictionary = players[player_id]
	return p.final_time if p.finished else p.elapsed


## Compare Player 1's finish time to the stored best and persist it if
## it's a new record. Sets previous_best / is_new_record for the results
## screen to read.
func _finalize_time_trial() -> void:
	var t: float = players[1].final_time
	previous_best = load_best_time()
	is_new_record = previous_best <= 0.0 or t < previous_best
	if is_new_record:
		_save_best_time(t)


## Best saved time-trial time, or 0.0 if none has been set yet.
func load_best_time() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SCORE_PATH) != OK:
		return 0.0
	return cfg.get_value("time_trial", "best_time", 0.0)


func _save_best_time(t: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SCORE_PATH)  # keep any other stored values; fresh if missing
	cfg.set_value("time_trial", "best_time", t)
	cfg.save(SCORE_PATH)


static func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	var millis := int(fmod(t, 1.0) * 1000.0)
	return "%02d:%02d.%03d" % [minutes, int(seconds), millis]
