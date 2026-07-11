extends Node3D
 
## ---------------------------------------------------------
## SMOOTH CHASE CAMERA
## Not parented to the skater — follows it independently so
## turns feel smooth instead of snapping instantly.
## Attach to a Node3D with a Camera3D child, place in the
## main scene (sibling of the skater, not a child of it).
## ---------------------------------------------------------
 
@export var target: Node3D              # assign the skater (CharacterBody3D) in the Inspector
@export var follow_distance: float = 5.0
@export var follow_height: float = 2.0
@export var look_height_offset: float = 1.0
 
@export var position_smoothing: float = 6.0  # higher = snappier
@export var rotation_smoothing: float = 4.0  # higher = snappier
 
func _physics_process(delta: float) -> void:
	if target == null:
		return
 
	# Desired position: behind the skater, offset by its current facing direction.
	var behind: Vector3 = target.global_transform.basis.z.normalized()  # +Z is "behind" since forward is -Z
	var desired_position: Vector3 = target.global_position \
		+ behind * follow_distance \
		+ Vector3.UP * follow_height
 
	global_position = global_position.lerp(desired_position, 1.0 - exp(-position_smoothing * delta))
 
	# Look at the skater (slightly above its base, roughly chest/head height).
	var look_target: Vector3 = target.global_position + Vector3.UP * look_height_offset
	var desired_transform: Transform3D = global_transform.looking_at(look_target, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(desired_transform.basis, 1.0 - exp(-rotation_smoothing * delta))
 
