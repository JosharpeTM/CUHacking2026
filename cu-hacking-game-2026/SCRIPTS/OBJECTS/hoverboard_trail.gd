extends Node3D

@export var base_amount: int = 120
@export var pulse_speed: float = 4.0
@export var pulse_strength: float = 60.0
@export var base_scale: float = 1.0
@export var scale_strength: float = 0.18

@onready var trail: GPUParticles3D = $Trail
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	var amt = int(base_amount + sin(_t * pulse_speed) * pulse_strength)
	trail.amount = max(0, amt)
	var s = base_scale + sin(_t * pulse_speed) * scale_strength
	trail.scale = Vector3.ONE * s
