extends Node

## ---------------------------------------------------------
## TIME TRIAL SCENE ROOT — single player, full screen
## Reuses the same track as the versus race, but drops Player 2
## and renders Player 1 straight to the main window (no split).
## The RaceManager runs in time-trial mode and saves the best
## time when the run finishes.
## ---------------------------------------------------------

@onready var player1: CharacterBody3D = $Track/Player1
@onready var p1_camera: Camera3D = $Track/Player1/SpringArm3D/Camera3D
@onready var timer_label: Label = $SharedHUD/TimerLabel

var _spawn_transform: Transform3D


func _ready() -> void:
	RaceManager.start_race(true)
	# Single-player: remove the second skater the shared track ships with.
	var p2: Node = $Track/Player2
	if p2:
		p2.queue_free()
	# Render Player 1's camera to the main window.
	p1_camera.make_current()
	process_priority = 100
	_spawn_transform = player1.global_transform


func _process(_delta: float) -> void:
	timer_label.text = RaceManager.format_time(RaceManager.race_elapsed)


func _physics_process(_delta: float) -> void:
	# Safety net: teleport the player back to spawn if they fall off the map.
	if player1.global_position.y < -20.0:
		player1.global_transform = _spawn_transform
		player1.velocity = Vector3.ZERO
		player1.current_speed = 0.0
