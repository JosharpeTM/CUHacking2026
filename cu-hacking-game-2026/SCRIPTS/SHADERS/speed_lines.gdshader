shader_type canvas_item;

// ---------------------------------------------------------
// RADIAL SPEED LINES
// Anime-style streaks that radiate in from the screen edges,
// growing longer/brighter and reaching further toward the
// centre as `intensity` rises. Drive `intensity` (0..1) from
// the player's speed (see race_hud.gd). At intensity 0 the
// shader outputs nothing, so it's free to leave on-screen.
// ---------------------------------------------------------

// 0 = calm (no lines), 1 = full-tilt streaks.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float line_count = 90.0;      // how many angular streaks around the ring
uniform float anim_speed = 8.0;       // how fast the streaks shimmer/stream
uniform float center_radius = 0.6;    // clear zone in the middle at full intensity (smaller = lines reach further in)
uniform float falloff = 0.35;         // softness of the edge ramp

// Cheap per-band hash for random line widths/phases.
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	// Centre the UV; dist ~0 at the middle, ~1 at the edges (larger in corners).
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x) / (2.0 * PI) + 0.5; // 0..1 around the circle

	// Split the ring into `line_count` bands and give each band a random line.
	float band = angle * line_count;
	float idx = floor(band);
	float frac_b = fract(band);
	float r = hash(idx);

	// A triangular bump centred in each band forms one thin radial streak; the
	// random width makes some lines fat and some hairline.
	float width = mix(0.03, 0.4, r);
	float line = smoothstep(0.5 - width, 0.5, frac_b) * smoothstep(0.5 + width, 0.5, frac_b);

	// Twinkle each streak on its own phase so the field feels like it's streaming.
	float twinkle = 0.5 + 0.5 * sin(TIME * anim_speed + r * 40.0);
	line *= mix(0.35, 1.0, twinkle);

	// Radial mask: nothing in the centre, ramping up toward the edges. As intensity
	// climbs, the clear zone shrinks so the streaks push further inward.
	float clear_r = mix(1.05, center_radius, intensity);
	float radial = smoothstep(clear_r, clear_r + falloff, dist);

	float alpha = line * radial * intensity;
	COLOR = vec4(line_color.rgb, line_color.a * alpha);
}
