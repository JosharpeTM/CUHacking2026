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
	# Join the shared group so the RaceManager can count how many checkpoints
	# the current track has (instead of assuming a fixed number). Distinct from
	# the "Checkpoint" group the HitBox already uses, so counting the roots isn't
	# doubled by the hitboxes.
	add_to_group("RaceCheckpoint")
	$HitBox.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and RaceManager.checkpoint_passed(body.player_id, checkpoint_index):
		$SFX.play()
		# Respawn point (Triangle/Y): centred on the gate and facing forward down
		# the track — not wherever the skater happened to be pointing (they may
		# have crossed sideways mid-drift).
		RaceManager.set_respawn(body.player_id, _respawn_transform(body))


## A clean, upright respawn transform for this gate. The gate collider is thin
## along its local Z, so ±Z is the direction of travel through it: we pick the
## sign matching the way the skater was driving, flatten it level (so a tilted
## gate doesn't pitch the respawn), and sit the skater on the gate's origin.
func _respawn_transform(body: Node3D) -> Transform3D:
	var gate_z: Vector3 = global_transform.basis.z
	var player_forward: Vector3 = -body.global_transform.basis.z
	var forward: Vector3 = gate_z if gate_z.dot(player_forward) > 0.0 else -gate_z
	forward.y = 0.0  # keep the board upright — no pitch from a ramped gate
	if forward.length() < 0.001:
		forward = player_forward  # near-vertical gate: fall back to travel dir
	forward = forward.normalized()
	# Basis.looking_at points -Z at `forward`, and the skater's forward is -Z.
	return Transform3D(Basis.looking_at(forward, Vector3.UP), global_position)
