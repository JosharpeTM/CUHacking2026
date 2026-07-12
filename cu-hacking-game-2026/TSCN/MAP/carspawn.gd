extends Node3D

@export var car_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 8.0
@export var speed: float = 10.0
@export var travel_distance: float = 800.0  # how far before despawn

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.autostart = true
	_timer.timeout.connect(_spawn_car)
	add_child(_timer)
	_spawn_car() # spawn one immediately

func _spawn_car() -> void:
	if car_scenes.is_empty():
		return

	var scene := car_scenes[randi() % car_scenes.size()]
	var car := scene.instantiate()
	get_tree().current_scene.add_child(car)

	# Spawn at this node's position/rotation (i.e. "through the wall")
	car.global_transform = global_transform

	if car.has_method("_physics_process") and car is Car:
		car.speed = speed
		car.direction = -global_transform.basis.z.normalized()
		car.despawn_z = global_position.dot(car.direction) + travel_distance
