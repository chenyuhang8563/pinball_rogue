shader_type canvas_item;

uniform float percent : hint_range(0.0, 1.0, 0.1);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 mask_color = vec4(flash_color.rgb, texture(TEXTURE, UV).a);
	COLOR = mix(texture(TEXTURE, UV), mask_color, percent);
}
