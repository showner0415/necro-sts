shader_type spatial;
// 바닥 표시 판: 2D 캔버스 그림을 그대로 입힌다. 벽에 가리되 깊이는 쓰지 않아서 몸을 가리지 않는다.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D marks : source_color, filter_nearest, repeat_disable;

void fragment() {
	vec4 color = texture(marks, UV);
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
