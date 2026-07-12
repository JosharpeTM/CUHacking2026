extends Control

@export var next_scene: String = "res://TSCN/UI/main_menu.tscn"
@export var hold_time: float = 3
@export var fade_time: float = 0.75
@export var video_length: float = 3.0

@onready var logo1: TextureRect = $Logo1
@onready var logo2: TextureRect = $Logo2
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	logo1.modulate.a = 0.0
	logo2.modulate.a = 0.0
	logo2.visible = false
	video_player.visible = false
	_play_sequence()

func _play_sequence() -> void:
	var tween := create_tween()

	# Logo 1: fade in, hold, fade out
	tween.tween_property(logo1, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(logo1, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func(): logo1.visible = false)

	# Logo 2: show, fade in, hold, fade out
	tween.tween_callback(func(): logo2.visible = true)
	tween.tween_property(logo2, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(logo2, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func(): logo2.visible = false)

	# Video: show, play, hold for its length
	tween.tween_callback(func():
		video_player.visible = true
		video_player.play()
	)
	tween.tween_property(VideoStreamPlayer, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)

	# Done -> go to main 
	tween.tween_property(VideoStreamPlayer, "modulate:a", 0.0, fade_time)
	tween.tween_callback(_go_to_next_scene)

	

func _go_to_next_scene() -> void:
	var err := get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("Scene change failed with error code: %s" % err)
