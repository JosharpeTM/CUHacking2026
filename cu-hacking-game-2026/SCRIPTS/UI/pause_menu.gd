extends Control

## ---------------------------------------------------------
## PAUSE MENU  (opened with the controller Menu / "settings" button)
## A full-window overlay that freezes the whole race — both skaters
## AND the shared clock — and offers a single Exit to Main Menu action.
##
## Freezing is done by pausing the SceneTree. That halts the pausable
## nodes: the skaters stop, and RaceManager (a normal autoload) stops
## ticking race_elapsed, so the timer freezes for free. Music keeps
## playing because MusicPlayer opts out with PROCESS_MODE_ALWAYS.
##
## Self-contained: drop this scene into any gameplay scene as a
## top-level overlay — it wires up nothing on the scene root. It runs
## with PROCESS_MODE_ALWAYS (set on the scene root node) so it still
## receives input while the rest of the tree is frozen, which lets the
## same button resume.
## ---------------------------------------------------------

@onready var exit_button: Button = $Center/Panel/Margin/VBox/ExitButton


func _ready() -> void:
	# Start hidden with the game running; the player opens it on demand.
	visible = false
	exit_button.pressed.connect(_on_exit)


func _unhandled_input(event: InputEvent) -> void:
	# The Menu / "settings" button toggles pause. While paused, B (ui_cancel)
	# also resumes, matching how the other menus back out.
	if event.is_action_pressed("pause"):
		_set_paused(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_set_paused(false)
		get_viewport().set_input_as_handled()


## Freeze/unfreeze the whole race and show/hide the overlay together.
func _set_paused(paused: bool) -> void:
	visible = paused
	get_tree().paused = paused
	if paused:
		# Focus the only button so it's immediately navigable on a controller.
		exit_button.grab_focus()


func _on_exit() -> void:
	# Lift the pause first, or the menu scene would load already frozen.
	get_tree().paused = false
	get_tree().change_scene_to_file(RaceManager.MENU_SCENE)
