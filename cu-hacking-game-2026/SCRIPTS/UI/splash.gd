extends Control

## ---------------------------------------------------------
## SPLASH SCREEN
## The game's first scene. Fades the custom splash image in
## from black, holds it, then fades back out to black before
## handing off to the main menu.
##
## Godot's native boot_splash can only show a static image,
## so the fade lives here in a real scene instead. The window
## starts black (boot_splash/bg_color) so the fade-in is
## seamless from launch.
##
## Any controller/key press skips straight to the menu.
## ---------------------------------------------------------

const MAIN_MENU := "res://TSCN/UI/main_menu.tscn"

const FADE_IN := 1.6
const HOLD := 2.4
const FADE_OUT := 1.6

@onready var logo: TextureRect = $Logo

var _done := false


func _ready() -> void:
	logo.modulate.a = 0.0

	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(logo, "modulate:a", 1.0, FADE_IN)
	tween.tween_interval(HOLD)
	tween.tween_property(logo, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_go_to_menu)


## Let the player skip the intro with any button/key.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventJoypadButton or event is InputEventKey):
		_go_to_menu()


func _go_to_menu() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(MAIN_MENU)
