extends Node3D

## ---------------------------------------------------------
## FINISH LINE
## Stops the crossing player's timer (only if they've passed
## every checkpoint) and fires a neon-purple burst. The
## RaceManager switches to the results scene once BOTH players
## have finished.
## ---------------------------------------------------------

# Neon-purple emission for the finish burst — matches the game's
# purple-on-black look.
const BURST_COLOR := Color(0.7, 0.25, 1.0)


func _ready() -> void:
	$HitBox.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and RaceManager.player_finished_at_line(body.player_id):
		$SFX.play()
		_play_finish_effect()


## Spawn a few expanding glowing rings that scale up and fade out, giving
## the finish line a neon shockwave when a racer crosses it. Everything is
## built (and freed) in code so it needs no scene setup and doesn't touch
## the shared finish-line materials.
func _play_finish_effect() -> void:
	for i in 3:
		var ring := _make_ring()
		add_child(ring)
		ring.global_position = global_position + Vector3(0.0, 0.6, 0.0)

		var mat: StandardMaterial3D = ring.material_override
		var delay := i * 0.12
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "scale", Vector3(6.0, 6.0, 6.0), 0.7).set_delay(delay)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.7).set_delay(delay)
		tween.chain().tween_callback(ring.queue_free)


func _make_ring() -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.9

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true
	mat.emission = BURST_COLOR
	mat.emission_energy_multiplier = 3.0
	mat.albedo_color = Color(BURST_COLOR, 0.9)

	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	# TorusMesh already lies flat in the XZ plane, so the ring expands
	# across the ground like a shockwave without any extra rotation.
	ring.scale = Vector3(0.3, 0.3, 0.3)
	return ring
