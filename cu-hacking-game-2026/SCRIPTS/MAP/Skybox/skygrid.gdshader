shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 grid_color : source_color = vec3(1.0, 0.1, 0.8);
uniform vec3 fog_color : source_color = vec3(0.04, 0.0, 0.08);

uniform float cell_size : hint_range(0.1, 50.0) = 10.0;
uniform float line_thickness : hint_range(0.01, 1.0) = 0.03;

uniform float fade_start : hint_range(0.0, 500.0) = 275.0;
uniform float fade_end : hint_range(0.0, 2000.0) = 900.0;

uniform float scroll_speed : hint_range(0.0, 50.0) = 8.0;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 scrolled_pos = world_pos.xz;
    scrolled_pos.y -= TIME * scroll_speed;

    vec2 grid_uv = fract(scrolled_pos / cell_size);
    vec2 line_dist = min(grid_uv, 1.0 - grid_uv);
    float line = min(line_dist.x, line_dist.y);

    float line_mask = 1.0 - step(line_thickness, line);

    float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
    float fade = 1.0 - smoothstep(fade_start, fade_end, dist);

    ALBEDO = mix(fog_color, grid_color, line_mask);
    ALPHA = clamp(fade, 0.0, 1.0);
}