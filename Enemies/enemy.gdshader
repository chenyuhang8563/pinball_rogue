shader_type canvas_item;

uniform float percent : hint_range(0.0, 1.0, 0.1);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float frost_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 frost_color : source_color = vec4(0.72, 0.92, 1.0, 1.0);
uniform vec4 snow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);


float snow_mask(vec2 uv) {
	float flakes = sin((uv.x * 61.0) + (uv.y * 113.0)) * sin((uv.x * 139.0) - (uv.y * 47.0));
	float edge_frost = smoothstep(0.26, 0.0, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	return clamp(step(0.72, flakes) * 0.45 + edge_frost * 0.55, 0.0, 1.0);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 frosted = mix(tex, vec4(frost_color.rgb, tex.a), frost_amount * 0.45);
	frosted.rgb = mix(frosted.rgb, snow_color.rgb, snow_mask(UV) * frost_amount * 0.75);
	vec4 mask_color = vec4(flash_color.rgb, tex.a);
	COLOR = mix(frosted, mask_color, percent);
}
