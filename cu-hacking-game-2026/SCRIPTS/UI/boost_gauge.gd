extends Control

## ---------------------------------------------------------
## NOS-STYLE BOOST GAUGE
## A radial gauge that fills with the racer's boost tank and
## flares with a neon-purple glow while boost is being spent.
## Driven by the race HUD via set_boost().
## ---------------------------------------------------------

const TRACK_COLOR := Color(0.14, 0.06, 0.22, 0.85)  # dark arc backing
const FILL_COLOR := Color(0.72, 0.32, 1.0, 1.0)     # neon purple fill
const GLOW_COLOR := Color(0.9, 0.55, 1.0, 1.0)      # brighter tint for the glow
const LOW_COLOR := Color(1.0, 0.35, 0.55, 1.0)      # warning tint when nearly empty

# Speedometer-style arc: opens at the bottom, sweeps clockwise.
const START_ANGLE := deg_to_rad(130.0)
const SWEEP := deg_to_rad(280.0)
const SEGMENTS := 20
const ARC_WIDTH := 10.0

var value := 50.0
var max_value := 100.0
var boosting := false

var _glow_phase := 0.0
var _boost_pulse := 0.0  # eases toward 1 while boosting, 0 otherwise

@onready var _readout: Label = $Readout


func _ready() -> void:
	pivot_offset = size / 2.0


func _process(delta: float) -> void:
	_glow_phase += delta * 6.0
	# Ease the glow up when boosting and back down when released.
	var target := 1.0 if boosting else 0.0
	_boost_pulse = lerp(_boost_pulse, target, 1.0 - exp(-delta * 12.0))

	# Subtle scale throb while boosting for extra punch (pivot from the centre).
	pivot_offset = size / 2.0
	var throb := 1.0 + 0.05 * _boost_pulse * (0.6 + 0.4 * sin(_glow_phase))
	scale = Vector2(throb, throb)

	queue_redraw()


## Update the gauge from the racer's current boost state.
func set_boost(amount: float, maxv: float, is_boosting: bool) -> void:
	value = amount
	max_value = maxv
	boosting = is_boosting
	if _readout:
		_readout.text = "%d" % int(round(amount))


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	var frac := clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	var fill_end := START_ANGLE + SWEEP * frac

	# Base fill colour warns red-ish when the tank runs low.
	var base := LOW_COLOR if frac <= 0.2 else FILL_COLOR
	var pulse := _boost_pulse * (0.7 + 0.3 * sin(_glow_phase))
	var fill_col := base.lerp(GLOW_COLOR, pulse)

	# Dark background track for the full sweep.
	draw_arc(center, radius, START_ANGLE, START_ANGLE + SWEEP, 64, TRACK_COLOR, ARC_WIDTH, true)

	# Soft glow underlay while boosting: a few progressively wider, fainter arcs.
	if pulse > 0.01:
		for i in 3:
			var w := ARC_WIDTH + float(i + 1) * 8.0 * pulse
			var a := 0.18 * pulse / float(i + 1)
			draw_arc(center, radius, START_ANGLE, fill_end, 64, Color(GLOW_COLOR, a), w, true)

	# Main fill arc.
	if frac > 0.0:
		draw_arc(center, radius, START_ANGLE, fill_end, 64, fill_col, ARC_WIDTH + 3.0 * pulse, true)

	# Tick marks around the rim — lit up to the current level.
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var ang := START_ANGLE + SWEEP * t
		var dir := Vector2(cos(ang), sin(ang))
		var inner := center + dir * (radius - 13.0)
		var outer := center + dir * (radius - 3.0)
		var col := fill_col if t <= frac else TRACK_COLOR
		draw_line(inner, outer, col, 2.0, true)
