extends Control

## ---------------------------------------------------------
## RACE RESULTS SCREEN
## Shown once both players have crossed the finish line.
## Reads final times from the RaceManager autoload and offers
## Play Again / Main Menu / Quit. Buttons are navigable with
## either controller's d-pad/stick + face buttons.
## ---------------------------------------------------------

@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var winner_label: Label = $CenterContainer/VBoxContainer/WinnerLabel
@onready var p1_time_label: Label = $CenterContainer/VBoxContainer/P1TimeLabel
@onready var p2_time_label: Label = $CenterContainer/VBoxContainer/P2TimeLabel
@onready var play_again_button: Button = $CenterContainer/VBoxContainer/Buttons/PlayAgainButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/Buttons/MenuButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Buttons/QuitButton


func _ready() -> void:
	# Guard for running this scene directly (F6) without a finished race.
	if not RaceManager.players.has(1):
		RaceManager.start_race()
		RaceManager.race_active = false

	if RaceManager.is_time_trial:
		_show_time_trial()
	else:
		_show_versus()

	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_menu)
	quit_button.pressed.connect(_on_quit)
	play_again_button.grab_focus()

	# The race scene's background load was consumed on the way into the race, so
	# re-request it now while the results are up — Play Again then swaps to an
	# already-parsed scene instead of hitching to reload the map.
	RaceManager.preload_race_scenes()


func _show_versus() -> void:
	title_label.text = "RACE RESULTS"
	var t1: float = RaceManager.players[1].final_time
	var t2: float = RaceManager.players[2].final_time

	p1_time_label.text = "PLAYER 1   %s" % RaceManager.format_time(t1)
	p2_time_label.text = "PLAYER 2   %s" % RaceManager.format_time(t2)

	if t1 < t2:
		winner_label.text = "PLAYER 1 WINS!"
	elif t2 < t1:
		winner_label.text = "PLAYER 2 WINS!"
	else:
		winner_label.text = "IT'S A TIE!"


func _show_time_trial() -> void:
	title_label.text = "TIME TRIAL"
	var t: float = RaceManager.players[1].final_time
	# After finishing, load_best_time() is the record including this run.
	var best: float = RaceManager.load_best_time()

	p1_time_label.text = "YOUR TIME   %s" % RaceManager.format_time(t)
	p2_time_label.text = "BEST TIME   %s" % RaceManager.format_time(best)

	if RaceManager.is_new_record:
		winner_label.text = "NEW RECORD!"
	else:
		winner_label.text = "FINISHED!"


func _on_play_again() -> void:
	var scene := RaceManager.TIME_TRIAL_SCENE if RaceManager.is_time_trial else RaceManager.RACE_SCENE
	RaceManager.change_scene_preloaded(scene)


func _on_menu() -> void:
	get_tree().change_scene_to_file(RaceManager.MENU_SCENE)


func _on_quit() -> void:
	get_tree().quit()
