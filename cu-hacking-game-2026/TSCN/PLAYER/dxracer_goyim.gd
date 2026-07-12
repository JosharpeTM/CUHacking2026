extends Node3D

## Animation clip names on the child AnimationPlayer. When your kickflip
## animations are done, name the two clips "Kickflip1"/"Kickflip2" (or set these
## fields in the Inspector to whatever you call them) — that's the only wiring
## left to do. Each X press plays a random one of the two.
@export var drive_anim: String = "Driving"
@export var kickflip_anims: Array[String] = ["Trick1", "Trick3_001"]

@onready var _anim: AnimationPlayer = $AnimationPlayer
var _kickflipping: bool = false


func _ready() -> void:
	_anim.play(drive_anim)
	# When any one-shot animation ends we fall back to the driving loop.
	_anim.animation_finished.connect(_on_animation_finished)


## Play a random kickflip once, then return to the driving loop. Called from the
## player controller on the X press. Safe to spam and safe to call before the
## animations exist — it just picks from whichever clips are actually present,
## and no-ops (with a warning) until at least one exists, so nothing breaks while
## you're still making them.
func kickflip() -> void:
	if _kickflipping:
		return
	# Only choose among clips that actually exist yet, so a missing/renamed one
	# never errors and the other still fires.
	var available: Array[String] = []
	for clip in kickflip_anims:
		if _anim.has_animation(clip):
			available.append(clip)
	if available.is_empty():
		push_warning("dxracer_goyim: no kickflip clips found (%s) — add them to the AnimationPlayer." % ", ".join(kickflip_anims))
		return
	_kickflipping = true
	_anim.play(available.pick_random())


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name in kickflip_anims:
		_kickflipping = false
		_anim.play(drive_anim)
