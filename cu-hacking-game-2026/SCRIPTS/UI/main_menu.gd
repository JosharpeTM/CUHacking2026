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
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Buttons/QuitButton
@onready var best_time_label: Label = $CenterContainer/VBoxContainer/BestTimeLabel
@onready var hint_label: Label = $CenterContainer/VBoxContainer/HintLabel


func _ready() -> void:
	race_button.pressed.connect(_on_race)
	time_trial_button.pressed.connect(_on_time_trial)
	quit_button.pressed.connect(_on_quit)

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
	# Keep focus on something reachable so controller navigation still works.
	if has_pad and not race_button.has_focus():
		race_button.grab_focus()
	elif not has_pad:
		quit_button.grab_focus()

 
func _on_race() -> void:
	RaceManager.change_scene_preloaded(RaceManager.RACE_SCENE)


func _on_time_trial() -> void:
	RaceManager.change_scene_preloaded(RaceManager.TIME_TRIAL_SCENE)


func _on_quit() -> void:
	get_tree().quit()
