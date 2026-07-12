extends Node3D
class_name Car

@export var speed: float = 10.0

var despawn_z: float = -50.0  # set by spawner
var direction: Vector3 = Vector3.FORWARD  # -Z by default in Godot

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	# Despawn once past the point (compares distance traveled along direction)
	if global_position.dot(direction) > despawn_z:
		queue_free()
