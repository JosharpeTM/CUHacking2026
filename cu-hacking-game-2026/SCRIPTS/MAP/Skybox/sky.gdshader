shader_type sky;

uniform vec3 top_color : source_color = vec3(0.08, 0.00, 0.11);
uniform vec3 horizon_color : source_color = vec3(0.48, 0.08, 0.65);
uniform vec3 bottom_color : source_color = vec3(0.5, 0.0, 0.0);

uniform float horizon_offset : hint_range(-0.5, 0.5) = -0.1;
uniform float top_spread : hint_range(0.1, 2.0) = 0.35;
uniform float bottom_spread : hint_range(0.1, 2.0) = 1;

uniform float star_density : hint_range(0.9, 0.999) = 0.998;
uniform float star_twinkle_speed : hint_range(0.0, 5.0) = 1.5;

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
    float t = EYEDIR.y - horizon_offset;
    vec3 col;

    if (t > 0.0) {
        col = mix(horizon_color, top_color, pow(t, top_spread));
    } else {
        col = mix(horizon_color, bottom_color, pow(-t, bottom_spread));
    }

    if (EYEDIR.y > 0.02) {
        vec3 star_coord = floor(EYEDIR * 400.0);
        float h = hash(star_coord);
        float star = step(star_density, h);

        float twinkle = 0.6 + 0.4 * sin(TIME * star_twinkle_speed + h * 40.0);
        float horizon_fade = smoothstep(0.0, 0.15, EYEDIR.y);

        col += vec3(star) * twinkle * horizon_fade;
    }

    COLOR = col;
}