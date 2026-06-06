shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 debris_color : source_color = vec4(0.95, 0.55, 0.20, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.28, 0.45);
uniform float orbit_radius : hint_range(0.05, 0.48, 0.01) = 0.34;
uniform float orbit_width : hint_range(0.005, 0.12, 0.005) = 0.035;
uniform float debris_size : hint_range(0.002, 0.08, 0.002) = 0.022;
uniform float debris_count : hint_range(4.0, 32.0, 1.0) = 14.0;
uniform float spin_speed : hint_range(-8.0, 8.0, 0.1) = 1.7;
uniform float jitter : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform bool show_source_texture = true;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453123);
}

float circle(vec2 point, vec2 center, float radius, float softness) {
	float distance_to_center = length(point - center);
	return 1.0 - smoothstep(radius, radius + softness, distance_to_center);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 center = vec2(0.5);
	vec2 point = UV - center;
	float distance_from_center = length(point);
	float angle = atan(point.y, point.x);

	float ring = 1.0 - smoothstep(orbit_width, orbit_width + 0.025, abs(distance_from_center - orbit_radius));
	float glow = ring * (0.18 + 0.12 * sin(TIME * 5.0));

	float debris_alpha = 0.0;
	vec3 debris_rgb = debris_color.rgb;

	for (int i = 0; i < 32; i++) {
		float index = float(i);
		if (index >= debris_count) {
			break;
		}

		float seed = index + 1.0;
		float base_angle = seed / debris_count * TAU;
		float random_offset = (hash(seed) - 0.5) * 0.55 * jitter;
		float wobble = sin(TIME * (1.4 + hash(seed + 8.0) * 2.4) + seed * 3.1) * 0.035 * jitter;
		float debris_angle = base_angle + TIME * spin_speed * (0.75 + hash(seed + 3.0) * 0.55) + random_offset;
		float debris_radius = orbit_radius + (hash(seed + 11.0) - 0.5) * orbit_width * 2.4 + wobble;
		vec2 debris_center = center + vec2(cos(debris_angle), sin(debris_angle)) * debris_radius;

		float size_variation = debris_size * (0.55 + hash(seed + 17.0) * 0.95);
		float sparkle = 0.65 + 0.35 * sin(TIME * (4.0 + hash(seed + 23.0) * 5.0) + seed);
		float particle = circle(UV, debris_center, size_variation, size_variation * 0.55) * sparkle;
		debris_alpha = max(debris_alpha, particle);
	}

	vec4 debris = vec4(debris_rgb, debris_alpha * debris_color.a * alpha);
	vec4 aura = vec4(glow_color.rgb, glow * glow_color.a * alpha);
	vec4 effect = aura + debris;

	if (show_source_texture) {
		COLOR = source;
		COLOR.rgb = mix(COLOR.rgb, effect.rgb, clamp(effect.a, 0.0, 1.0));
		COLOR.a = max(COLOR.a, effect.a);
	} else {
		COLOR = effect;
	}
}
