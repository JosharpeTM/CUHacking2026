extends Node3D

## ---------------------------------------------------------
## BOOST PAD
## A pickup that tops up a racer's boost tank when driven over,
## then goes dark and respawns after a delay (Rocket-League
## style). Set boost_value / respawn_time per instance.
## ---------------------------------------------------------

@export var boost_value: float = 34.0   # boost units granted on pickup
@export var respawn_time: float = 5.0   # seconds until the pad returns

var _active: bool = true

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $HitBox


func _ready() -> void:
	_hitbox.body_entered.connect(_on_body_entered)
	# Slow neon spin so the pad reads as "live" and pickable.
	var spin := create_tween().set_loops()
	spin.tween_property(_visual, "rotation:y", TAU, 3.0).from(0.0)


func _on_body_entered(body: Node3D) -> void:
	if not _active or not body.is_in_group("Player") or not body.has_method("add_boost"):
		return
	# Only consume the pad if the racer actually had room for boost.
	if body.add_boost(boost_value) > 0.0:
		_pickup()


## Hide + disable the pad, then bring it back after respawn_time.
func _pickup() -> void:
	_active = false
	_visual.visible = false
	# Deferred: we're inside the physics body_entered callback.
	_hitbox.set_deferred("monitoring", false)
	if has_node("SFX"):
		$SFX.play()

	await get_tree().create_timer(respawn_time).timeout

	_active = true
	_visual.visible = true
	_hitbox.set_deferred("monitoring", true)
