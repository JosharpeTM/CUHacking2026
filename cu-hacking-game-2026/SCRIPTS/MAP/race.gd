extends Node

## ---------------------------------------------------------
## RACE SCENE ROOT — left/right split-screen
## The whole track (with both players) lives inside SV1.
## Both SubViewports share the root World3D (own_world_3d is
## off), so SV2 only needs its own Camera3D — every frame we
## copy Player 2's in-world camera transform onto it.
## ---------------------------------------------------------

@onready var p1_camera: Camera3D = $HBoxContainer/SVC1/SV1/Track/Player1/SpringArm3D/Camera3D
@onready var p2_world_camera: Camera3D = $HBoxContainer/SVC1/SV1/Track/Player2/SpringArm3D/Camera3D
@onready var p2_view_camera: Camera3D = $HBoxContainer/SVC2/SV2/P2Camera
@onready var timer_label: Label = $SharedHUD/TimerLabel
@onready var divider: Panel = $HBoxContainer/Divider
@onready var players := {
	1: $HBoxContainer/SVC1/SV1/Track/Player1,
	2: $HBoxContainer/SVC1/SV1/Track/Player2,
}

var _spawn_transforms := {}


func _ready() -> void:
	RaceManager.start_race()
	# Both players' cameras live in SV1's tree; force Player 1's to be
	# the one SV1 renders. Run after the SpringArms update so the copied
	# transform is never a frame behind.
	p1_camera.make_current()
	process_priority = 100
	for pid in players:
		_spawn_transforms[pid] = players[pid].global_transform

	# Pulse the split-screen divider's neon glow so the seam feels alive.
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(divider, "self_modulate", Color(1, 1, 1, 1), 0.9)
	pulse.tween_property(divider, "self_modulate", Color(0.7, 0.7, 0.85, 1), 0.9)


func _process(_delta: float) -> void:
	p2_view_camera.global_transform = p2_world_camera.global_transform
	# One shared race clock, drawn once in the middle of the screen.
	timer_label.text = RaceManager.format_time(RaceManager.race_elapsed)


func _physics_process(_delta: float) -> void:
	# Safety net: teleport anyone who falls off the map back to their spawn.
	for pid in players:
		var player: CharacterBody3D = players[pid]
		if player.global_position.y < -20.0:
			player.global_transform = _spawn_transforms[pid]
			player.velocity = Vector3.ZERO
			player.current_speed = 0.0
