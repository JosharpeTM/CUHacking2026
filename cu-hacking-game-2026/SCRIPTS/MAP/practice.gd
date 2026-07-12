extends Node

## ---------------------------------------------------------
## PRACTICE SCENE ROOT — single player, free drive
## Reuses the test map and just lets Player 1 cruise around:
## no countdown, no timer, no checkpoints, no racing. The
## on-screen driving controls in the top-left stay up the
## whole time as a reference. Great for learning the handling.
## ---------------------------------------------------------

@onready var player1: CharacterBody3D = $Track/Player1
@onready var p1_camera: Camera3D = $Track/Player1/SpringArm3D/Camera3D
# The shared race HUD ships with a lap counter that means nothing here, so we
# hide it — the boost gauge and speed effects it also carries are still welcome.
@onready var _lap_label: Label = $HUD/LapLabel

var _spawn_transform: Transform3D


func _ready() -> void:
	RaceManager.start_practice()

	# Single-player: drop the second skater the test map ships with.
	var p2: Node = $Track/Player2
	if p2:
		p2.queue_free()

	# The test map autoplays the race countdown sound; there's no countdown in
	# practice, so silence it.
	var countdown_audio: Node = $Track.get_node_or_null("AudioStreamPlayer")
	if countdown_audio:
		countdown_audio.queue_free()

	_lap_label.visible = false

	# Render Player 1's camera to the main window.
	p1_camera.make_current()
	process_priority = 100
	_spawn_transform = player1.global_transform


func _physics_process(_delta: float) -> void:
	# Safety net: teleport the player back to spawn if they fall off the map.
	if player1.global_position.y < -20.0:
		player1.global_transform = _spawn_transform
		player1.velocity = Vector3.ZERO
		player1.current_speed = 0.0
