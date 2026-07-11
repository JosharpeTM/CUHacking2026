extends Control

## ---------------------------------------------------------
## MAIN MENU
## The game's entry point. Starts the split-screen race or
## quits. Buttons are navigable with either controller's
## d-pad (built-in ui_* actions) or the keyboard.
## ---------------------------------------------------------

@onready var play_button: Button = $CenterContainer/VBoxContainer/Buttons/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Buttons/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(_on_quit)
	play_button.grab_focus()


func _on_play() -> void:
	get_tree().change_scene_to_file(RaceManager.RACE_SCENE)


func _on_quit() -> void:
	get_tree().quit()
