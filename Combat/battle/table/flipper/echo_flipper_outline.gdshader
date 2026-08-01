// echo_flipper_outline.gdshader —— 挡板回响蓄力外轮廓。
// 复用 marble_outline.gdshader 的外轮廓检测算法，增加黄/红双色进度：
//   yellow_progress (0..1)：黄色轮廓从挡板一端向另一端增长，包裹满整个挡板；
//   red_progress (0..1)   ：黄色包裹满后，红色轮廓从同一端开始增长。
// 0 进度时无任何轮廓（无 BROWN 弹珠时 progress 恒为 0，视觉上即无蓄力显示）。
shader_type canvas_item;

uniform vec4 yellow_clr : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec4 red_clr : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float yellow_progress = 0.0;
uniform float red_progress = 0.0;
uniform float thickness = 1.0;

const vec2[8] DIRECTIONS = {
	vec2(1.0, 0.0),
	vec2(0.0, 1.0),
	vec2(-1.0, 0.0),
	vec2(0.0, -1.0),
	vec2(1.0, 1.0),
	vec2(-1.0, 1.0),
	vec2(-1.0, -1.0),
	vec2(1.0, -1.0)
};

float gtz(float input) { return max(0, sign(input)); }
// returns 1 if input > 0, else 0

// 方形外轮廓（8 方向），与弹珠 marble_outline 的 type=Square 一致。
float check(sampler2D tex, vec2 from, vec2 size) {
	float result = 0.0;
	for (int i = 0; i < 8; i++) {
		result += texture(tex, from + DIRECTIONS[i] * size * thickness).a;
	}
	return gtz(result);
}

void fragment() {
	float outline = check(TEXTURE, UV, TEXTURE_PIXEL_SIZE) * (1.0 - gtz(COLOR.a));
	// 黄条从 UV.x=0 一侧增长到 1（包裹满挡板）；红色随后叠加覆盖。
	float yellow_mask = gtz(yellow_progress - UV.x + 0.001);
	float red_mask = gtz(red_progress - UV.x + 0.001);
	COLOR = mix(COLOR, yellow_clr, outline * yellow_mask);
	COLOR = mix(COLOR, red_clr, outline * red_mask);
}
