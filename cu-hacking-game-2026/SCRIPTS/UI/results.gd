extends Control

## ---------------------------------------------------------
## RACE RESULTS SCREEN
## Shown once both players have crossed the finish line.
## Reads final times from the RaceManager autoload and offers
## Play Again / Quit. Buttons are navigable with either
## controller's d-pad (built-in ui_* actions) or keyboard.
## ---------------------------------------------------------

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

	var t1: float = RaceManager.players[1].final_time
	var t2: float = RaceManager.players[2].final_time

	p1_time_label.text = "Player 1   %s" % RaceManager.format_time(t1)
	p2_time_label.text = "Player 2   %s" % RaceManager.format_time(t2)

	if t1 < t2:
		winner_label.text = "Player 1 wins!"
	elif t2 < t1:
		winner_label.text = "Player 2 wins!"
	else:
		winner_label.text = "It's a tie!"

	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_menu)
	quit_button.pressed.connect(_on_quit)
	play_again_button.grab_focus()


func _on_play_again() -> void:
	get_tree().change_scene_to_file(RaceManager.RACE_SCENE)


func _on_menu() -> void:
	get_tree().change_scene_to_file(RaceManager.MENU_SCENE)


func _on_quit() -> void:
	get_tree().quit()
