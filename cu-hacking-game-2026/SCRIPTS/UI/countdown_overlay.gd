extends Label

## ---------------------------------------------------------
## "3 2 1 GO" COUNTDOWN OVERLAY
## A big centered neon-purple number that pops in each second
## of the pre-race countdown (driven by RaceManager.countdown_tick),
## then flashes "GO!" and fades away. Purely cosmetic — the actual
## race gating lives in RaceManager.
## ---------------------------------------------------------

# Neon purple for 3/2/1, and a brighter magenta pop for GO!
const NUMBER_COLOR := Color(0.72, 0.35, 1.0, 1.0)
const GO_COLOR := Color(0.92, 0.55, 1.0, 1.0)

var _tween: Tween


func _ready() -> void:
	visible = false
	pivot_offset = size / 2.0
	RaceManager.countdown_tick.connect(_on_countdown_tick)


func _on_countdown_tick(value: int) -> void:
	if value > 0:
		_flash(str(value), NUMBER_COLOR, false)
	else:
		_flash("GO!", GO_COLOR, true)


## Pop the label in big and bright, then shrink + fade it out. `is_go`
## fades a touch slower and doesn't shrink as hard, so "GO!" reads as a
## release rather than another tick.
func _flash(new_text: String, color: Color, is_go: bool) -> void:
	text = new_text
	self_modulate = color
	visible = true

	# Recompute the centre in case the font sizing changed the label bounds.
	pivot_offset = size / 2.0

	if _tween and _tween.is_valid():
		_tween.kill()

	scale = Vector2(0.4, 0.4)
	modulate.a = 1.0

	var hold := 0.9 if is_go else 0.6
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Punchy overshoot, then settle back to full size.
	_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.22)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.13).set_trans(Tween.TRANS_SINE)
	# Fade out alongside the settle so the number lingers, then hide.
	_tween.parallel().tween_property(self, "modulate:a", 0.0, hold).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: visible = false)
