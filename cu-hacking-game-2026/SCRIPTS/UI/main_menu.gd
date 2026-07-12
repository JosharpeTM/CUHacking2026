extends Control

## ---------------------------------------------------------
## MAIN MENU
## The game's entry point. Starts a 2-player race or a
## single-player time trial, and shows the saved best
## time-trial time.
##
## The game is controller-only: menus are driven with either
## controller's d-pad/stick + face buttons (the ui_* actions
## are remapped to joypad in project.godot). If no controller
## is connected we show a hint and disable the play buttons.
## ---------------------------------------------------------

@onready var title: Label = $CenterContainer/VBoxContainer/Title
@onready var race_button: Button = $CenterContainer/VBoxContainer/Buttons/RaceButton
@onready var time_trial_button: Button = $CenterContainer/VBoxContainer/Buttons/TimeTrialButton
@onready var practice_button: Button = $CenterContainer/VBoxContainer/Buttons/PracticeButton
@onready var controls_button: Button = $CenterContainer/VBoxContainer/Buttons/ControlsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Buttons/QuitButton
@onready var best_time_label: Label = $CenterContainer/VBoxContainer/BestTimeLabel
@onready var hint_label: Label = $CenterContainer/VBoxContainer/HintLabel

@onready var controls_panel: Panel = $ControlsPanel
@onready var back_button: Button = $ControlsPanel/Center/VBox/BackButton
@onready var _drive_grid: GridContainer = $ControlsPanel/Center/VBox/DriveGrid
@onready var _menu_grid: GridContainer = $ControlsPanel/Center/VBox/MenuGrid

# The control scheme shown on the Controls page: [action, button] rows. Every
# skater uses their own controller with the same layout. Keep in sync with the
# input map in project.godot and playerController.gd.
const DRIVE_CONTROLS := [
	["Accelerate", "Right Trigger"],
	["Brake / Reverse", "Left Trigger"],
	["Steer", "Left Stick"],
	["Look Around", "Right Stick"],
	["Jump", "A  /  Cross"],
	["Boost  (hold)", "B  /  Circle"],
	["Drift  (hold + steer)", "R1  /  RB"],
	["Respawn at Checkpoint", "Y  /  Triangle"],
]
const MENU_CONTROLS := [
	["Navigate", "D-Pad  /  Left Stick"],
	["Select", "A  /  Cross"],
	["Back", "B  /  Circle"],
]


func _ready() -> void:
	race_button.pressed.connect(_on_race)
	time_trial_button.pressed.connect(_on_time_trial)
	practice_button.pressed.connect(_on_practice)
	controls_button.pressed.connect(_open_controls)
	back_button.pressed.connect(_close_controls)
	quit_button.pressed.connect(_on_quit)

	_populate_controls(_drive_grid, DRIVE_CONTROLS)
	_populate_controls(_menu_grid, MENU_CONTROLS)

	# Start loading the playable scenes on a background thread now, while the
	# player is reading the menu, so pressing Play swaps to an already-parsed
	# scene instead of hitching to load the map on the spot.
	RaceManager.preload_race_scenes()
	# Then render the heavy city map once offscreen so its shaders compile now
	# (the real hitch) rather than on the first race frame. Deferred so the
	# background load above has a chance to finish before we pull the map in.
	RaceManager.warm_up_map.call_deferred()

	_start_title_glow()

	var best: float = RaceManager.load_best_time()
	if best > 0.0:
		best_time_label.text = "BEST TIME TRIAL:  %s" % RaceManager.format_time(best)
	else:
		best_time_label.text = "BEST TIME TRIAL:  --:--.---"

	# React to controllers being plugged in / removed while on the menu.
	# _refresh_controller_state() also sets the initial focus.
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_controller_state()


## Pulse the title's neon outline forever so it reads as a live glow.
func _start_title_glow() -> void:
	var dim := Color(0.55, 0.12, 1, 0.35)
	var bright := Color(0.75, 0.3, 1, 0.95)
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(title, "theme_override_colors/font_outline_color", bright, 1.1)
	tween.tween_property(title, "theme_override_colors/font_outline_color", dim, 1.1)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller_state()


## Enable the play buttons only while at least one controller is connected,
## and toggle the "connect a controller" hint to match.
func _refresh_controller_state() -> void:
	var has_pad: bool = not Input.get_connected_joypads().is_empty()
	hint_label.visible = not has_pad
	race_button.disabled = not has_pad
	time_trial_button.disabled = not has_pad
	practice_button.disabled = not has_pad
	# The Controls page stays reachable even without a controller so players can
	# read the layout. While it's open, leave its focus alone.
	if controls_panel.visible:
		return
	# Keep focus on something reachable so controller navigation still works.
	if has_pad and not race_button.has_focus():
		race_button.grab_focus()
	elif not has_pad:
		quit_button.grab_focus()

 
## Fill a 2-column grid with [action, button] rows: the action label is right-
## aligned in purple, the button label left-aligned in cyan, so they read as a
## tidy table down the middle.
func _populate_controls(grid: GridContainer, rows: Array) -> void:
	for row in rows:
		grid.add_child(_make_cell(row[0], Color(0.85, 0.7, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(_make_cell(row[1], Color(0.65, 0.95, 1, 1), HORIZONTAL_ALIGNMENT_LEFT))


func _make_cell(text: String, color: Color, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = align
	return lbl


## Show the Controls overlay and move focus to its Back button so a controller
## can dismiss it with the face button or ui_cancel (B). The menu buttons behind
## the (opaque) panel are made non-focusable so d-pad navigation can't jump onto
## a covered button.
func _open_controls() -> void:
	controls_panel.visible = true
	_set_menu_focusable(false)
	back_button.grab_focus()


func _close_controls() -> void:
	controls_panel.visible = false
	_set_menu_focusable(true)
	controls_button.grab_focus()


func _set_menu_focusable(on: bool) -> void:
	var mode := Control.FOCUS_ALL if on else Control.FOCUS_NONE
	for b in [race_button, time_trial_button, practice_button, controls_button, quit_button]:
		b.focus_mode = mode


## Let B / ui_cancel back out of the Controls page.
func _input(event: InputEvent) -> void:
	if controls_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_controls()
		get_viewport().set_input_as_handled()


func _on_race() -> void:
	RaceManager.change_scene_preloaded(RaceManager.RACE_SCENE)


func _on_time_trial() -> void:
	RaceManager.change_scene_preloaded(RaceManager.TIME_TRIAL_SCENE)


func _on_practice() -> void:
	RaceManager.change_scene_preloaded(RaceManager.PRACTICE_SCENE)


func _on_quit() -> void:
	get_tree().quit()
