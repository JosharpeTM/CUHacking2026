extends Node3D

## ---------------------------------------------------------
## FINISH LINE
## Stops the crossing player's timer (only if they've passed
## every checkpoint). The RaceManager switches to the results
## scene once BOTH players have finished.
## ---------------------------------------------------------


func _ready() -> void:
	$HitBox.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and RaceManager.player_finished_at_line(body.player_id):
		$SFX.play()
