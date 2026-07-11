shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

// ---- Neon Shell / Wireframe hologram ----
// Rim-lit "shell" glow + screen-space anti-aliased wireframe grid.
// Tuned to match the game's purple/magenta neon palette.

uniform vec3 wire_color : source_color = vec3(0.698, 0.545, 0.996); // PurpleNeon
uniform vec3 rim_color  : source_color = vec3(0.741, 0.0, 0.741);   // CityNeon magenta
uniform vec3 fill_color : source_color = vec3(0.04, 0.0, 0.08);     // dark inner tint

uniform float emission_energy : hint_range(0.0, 12.0) = 5.0;

// Wireframe grid drawn from UVs (fwidth-antialiased so lines stay crisp at any distance)
uniform float wire_density : hint_range(1.0, 200.0) = 24.0;
uniform float wire_thickness : hint_range(0.5, 6.0) = 1.4;

// Fresnel rim ("shell") glow
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 4.0) = 1.6;

// Animated scan sweep travelling along local Y
uniform float scan_speed : hint_range(0.0, 10.0) = 1.5;
uniform float scan_width : hint_range(0.0, 1.0) = 0.06;
uniform float scan_strength : hint_range(0.0, 4.0) = 1.2;

// Overall opacity of the empty (non-line) area — lower = more see-through hologram
uniform float fill_alpha : hint_range(0.0, 1.0) = 1;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// Anti-aliased grid line mask from a set of UVs.
float grid_lines(vec2 uv, float density, float thickness) {
	vec2 g = uv * density;
	vec2 grid = abs(fract(g - 0.5) - 0.5);
	vec2 fw = fwidth(g);
	vec2 lines = smoothstep(fw * thickness, vec2(0.0), grid);
	return clamp(max(lines.x, lines.y), 0.0, 1.0);
}

void fragment() {
	// --- Wireframe from UVs ---
	float wire = grid_lines(UV, wire_density, wire_thickness);

	// --- Fresnel rim / shell glow ---
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	fresnel *= rim_strength;

	// --- Scan sweep along local Y ---
	float sweep = fract(local_pos.y * 0.5 - TIME * scan_speed);
	float scan = smoothstep(scan_width, 0.0, min(sweep, 1.0 - sweep)) * scan_strength;

	// --- Compose color ---
	vec3 col = fill_color;
	col = mix(col, wire_color, wire);        // wireframe lines
	col += rim_color * fresnel;              // outer shell glow
	col += wire_color * scan;                // travelling scan line

	ALBEDO = col;
	EMISSION = col * emission_energy;

	// --- Alpha: lines + rim + scan opaque, interior see-through ---
	float alpha = max(max(wire, fresnel), scan);
	alpha = max(alpha, fill_alpha);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
