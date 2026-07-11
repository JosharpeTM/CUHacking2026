extends Node3D

## ---------------------------------------------------------
## CHECKPOINT GATE
## When a player drives through the HitBox, records their
## time split with the RaceManager and plays a chime.
## Set checkpoint_index per instance (0, 1, 2, ...) — gates
## only count in order, so re-entering one does nothing.
## ---------------------------------------------------------

@export var checkpoint_index: int = 0


func _ready() -> void:
	$HitBox.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and RaceManager.checkpoint_passed(body.player_id, checkpoint_index):
		$SFX.play()
