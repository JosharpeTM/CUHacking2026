extends Node

## ---------------------------------------------------------
## RACE MANAGER (autoload singleton)
## Owns all race state: per-player timers, checkpoint splits,
## finish times. Survives scene changes, so the results screen
## can read the final times after the race scene is gone.
## ---------------------------------------------------------

signal split_recorded(player_id: int, checkpoint_index: int, split_time: float)
signal player_finished(player_id: int, final_time: float)
# Emitted when a player crosses the finish line but still has laps to go.
# `new_lap` is the lap they are now starting (2..TOTAL_LAPS). The HUD listens
# to update its LAP counter.
signal lap_completed(player_id: int, new_lap: int, total_laps: int)
# Emitted each second of the pre-race countdown. value counts 3 -> 2 -> 1,
# then 0 to signal "GO!". The HUD listens to animate the 3-2-1-GO overlay.
signal countdown_tick(value: int)

# How many laps a race lasts. You only win by crossing the finish line on the
# final lap — earlier crossings just start the next lap.
const TOTAL_LAPS := 3

# Fallback checkpoint count, used only if a scene somehow has no checkpoints
# (e.g. running the results screen directly). The real value is recomputed from
# the track's checkpoints at the start of every race — see start_race().
const DEFAULT_CHECKPOINTS := 3
var total_checkpoints := DEFAULT_CHECKPOINTS
# How many seconds the "3 2 1 GO" countdown runs before the racers are freed.
const COUNTDOWN_SECONDS := 3
const MENU_SCENE := "res://TSCN/UI/main_menu.tscn"
const RACE_SCENE := "res://TSCN/MAP/race.tscn"
const TIME_TRIAL_SCENE := "res://TSCN/MAP/time_trial.tscn"
const RESULTS_SCENE := "res://TSCN/UI/results.tscn"
# The heavy shared geometry both race modes embed (a 21 MB GLB city). Warmed up
# on the menu so its shaders don't compile on the first race frame.
const MAP_SCENE := "res://TSCN/MAP/neon_city.tscn"

# Where the best time-trial time is persisted between sessions.
const SCORE_PATH := "user://scores.cfg"

var race_active := false
var input_locked := false  # true during the countdown: skaters can't move yet
var race_elapsed := 0.0  # shared race clock, runs until every racer finishes
var players := {}  # player_id -> {elapsed, splits: Array, next_cp, lap, finished, final_time}

# Where each player respawns when they press Triangle/Y: their start spawn at
# first, then the last checkpoint they cleared. Kept OUTSIDE `players` so it
# survives start_race() resets — the skaters register their spawn from _ready(),
# which runs before the race scene root calls start_race().
var respawn_points := {}  # player_id -> Transform3D

# Mode + time-trial result state, read by the results screen.
var is_time_trial := false
var previous_best := 0.0   # best time BEFORE this run (0.0 == no record yet)
var is_new_record := false # did the run just set a new best?

# Shader warm-up state (see warm_up_map).
var _map_warmed := false
var _warm_viewport: SubViewport = null


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


## --- Scene preloading -------------------------------------------------
## Loading the race / time-trial scenes (the neon city map especially) on the
## frame the player presses Play causes a visible hitch. Instead we start
## loading them on a background thread while the menu is up, then swap to the
## already-parsed scene instantly. The menu calls preload_race_scenes() from
## its _ready() and change_scene_preloaded() from its buttons.

## Kick off background loads for the playable scenes. Safe to call repeatedly —
## a path already loading or loaded is skipped.
func preload_race_scenes() -> void:
	for path in [RACE_SCENE, TIME_TRIAL_SCENE]:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)


## Switch to a scene we (hopefully) preloaded in the background. If preloading
## already finished this swaps with no disk hit; otherwise it blocks only for
## whatever loading remains, and falls back to a plain load if anything failed.
func change_scene_preloaded(path: String) -> void:
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# Never requested (or already consumed) — start it now.
		if ResourceLoader.load_threaded_request(path) != OK:
			get_tree().change_scene_to_file(path)
			return
	# Blocks until the load finishes; returns immediately if it already has.
	var scene := ResourceLoader.load_threaded_get(path)
	if scene is PackedScene:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(path)


## Compile the neon city's shaders and upload its meshes/textures to the GPU
## ahead of time, so the first race frame doesn't hitch while the Forward+
## renderer compiles them on the spot. We render the map once in a tiny hidden
## SubViewport and keep it resident for the session (shaders are cached engine-
## wide once compiled, and holding the instance keeps its GPU buffers warm).
## Only the static geometry is instanced — no scripts, players or HUD — so this
## has no effect on game state. Safe to call repeatedly; only the first does work.
func warm_up_map() -> void:
	if _map_warmed:
		return
	_map_warmed = true

	var packed := load(MAP_SCENE) as PackedScene
	if packed == null:
		_map_warmed = false  # let a later call retry if the load isn't ready yet
		return

	# Tiny offscreen viewport with its own world so it never shows on screen or
	# touches the real game world. UPDATE_ONCE renders a single frame — enough to
	# force shader compilation — then stops, so it costs nothing ongoing.
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	# A directional light with shadows + a glow environment so the *lit/shadowed*
	# material variants and the glow post-pass compile now too — those are exactly
	# what the real race scene uses, so nothing is left to compile on the spot.
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	vp.add_child(light)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.glow_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	var map := packed.instantiate()
	vp.add_child(map)

	# Frame the whole city so every material is inside the frustum and actually
	# gets drawn (and thus compiled) this frame — a camera that sees nothing
	# would compile nothing.
	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	add_child(vp)  # in-tree so global transforms (for the AABB) are valid
	_aim_camera_at(cam, _world_aabb(map))

	_warm_viewport = vp


## Merged world-space bounds of every VisualInstance3D under `node`.
func _world_aabb(node: Node) -> AABB:
	var bounds := AABB()
	var seeded := false
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var vi := child as VisualInstance3D
		var world_box := vi.global_transform * vi.get_aabb()
		if not seeded:
			bounds = world_box
			seeded = true
		else:
			bounds = bounds.merge(world_box)
	return bounds


## Pull the camera back so the whole AABB fits in view.
func _aim_camera_at(cam: Camera3D, bounds: AABB) -> void:
	if bounds.size == Vector3.ZERO:
		return
	var center := bounds.get_center()
	var radius := bounds.size.length() * 0.5
	cam.far = maxf(radius * 5.0, 100.0)
	cam.global_position = center + Vector3(radius, radius, radius)
	cam.look_at(center, Vector3.UP)


## Reset all race state and start the clocks. Called by the race scene
## when it loads (so "Play Again" resets everything for free).
## Pass time_trial=true for the single-player (Player 1 only) mode.
func start_race(time_trial := false) -> void:
	is_time_trial = time_trial
	is_new_record = false
	previous_best = 0.0
	# Count the checkpoints the current track actually has, so tracks can carry
	# any number of them without touching this script. Falls back to the default
	# if none are present (e.g. results screen run directly).
	var cp_count := get_tree().get_nodes_in_group("RaceCheckpoint").size()
	total_checkpoints = cp_count if cp_count > 0 else DEFAULT_CHECKPOINTS

	var ids: Array = [1] if time_trial else [1, 2]
	players = {}
	for pid in ids:
		players[pid] = {
			"elapsed": 0.0,
			"splits": [],
			"next_cp": 0,
			"lap": 1,  # laps 1..TOTAL_LAPS; you win by finishing the last one
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


## Record where a player should reappear when they press Triangle/Y. Skaters
## call this from _ready() with their spawn, and checkpoints call it (with the
## crossing skater's transform) each time a gate is cleared.
func set_respawn(player_id: int, xform: Transform3D) -> void:
	respawn_points[player_id] = xform


## The player's current respawn transform (last checkpoint, or spawn). Falls
## back to identity if nothing has been registered yet.
func get_respawn(player_id: int) -> Transform3D:
	return respawn_points.get(player_id, Transform3D.IDENTITY)


## Called by the finish line. Only counts once per lap, and only after all of
## this lap's checkpoints have been passed. Crossing on an earlier lap just
## resets the checkpoints and starts the next lap; only crossing on the final
## lap actually finishes the player. When BOTH players are done, switch to the
## results scene.
func player_finished_at_line(player_id: int) -> bool:
	if not race_active or not players.has(player_id):
		return false
	var p: Dictionary = players[player_id]
	if p.finished or p.next_cp < total_checkpoints:
		return false

	if p.lap < TOTAL_LAPS:
		# Lap complete, but not the last one — go around again.
		p.lap += 1
		p.next_cp = 0
		lap_completed.emit(player_id, p.lap, TOTAL_LAPS)
		return true

	# Final lap crossed — this player is done.
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
