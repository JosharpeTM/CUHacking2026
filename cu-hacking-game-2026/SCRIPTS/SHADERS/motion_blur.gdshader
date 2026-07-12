shader_type canvas_item;

// ---------------------------------------------------------
// RADIAL (ZOOM) MOTION BLUR
// A screen-space post effect: each pixel is smeared toward the
// centre of the screen, so at speed the world streaks radially
// outward like a zoom/warp. `strength` (0..1) is driven by the
// player's speed (see race_hud.gd); at 0 the screen passes
// through untouched. The very centre is kept sharp so the focal
// point (the racer) doesn't turn to mush.
//
// Lives on a full-screen ColorRect inside each player's HUD, so
// it reads that player's SubViewport and stays per-split-screen.
// ---------------------------------------------------------

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;  // 0 = off, 1 = full smear
uniform float max_blur = 0.045;    // furthest sample offset at full strength (fraction of screen)
uniform float center_clear = 0.12; // radius kept sharp in the middle (fraction of screen)

const int SAMPLES = 10;  // more = smoother/heavier smear

void fragment() {
	vec4 base = texture(screen_tex, SCREEN_UV);

	// Direction from screen centre out to this pixel; blur smears back along it.
	vec2 dir = SCREEN_UV - vec2(0.5);
	float dist = length(dir);

	// Ease the blur in from the centre so the middle stays crisp and it ramps
	// toward the edges, then scale the whole thing by speed-driven strength.
	float edge = smoothstep(center_clear, 0.7, dist);
	float amount = strength * edge * max_blur;

	if (amount <= 0.0001) {
		COLOR = base;
	} else {
		vec4 sum = base;
		for (int i = 1; i <= SAMPLES; i++) {
			float t = float(i) / float(SAMPLES);
			sum += texture(screen_tex, SCREEN_UV - dir * amount * t);
		}
		COLOR = sum / float(SAMPLES + 1);
	}
}
