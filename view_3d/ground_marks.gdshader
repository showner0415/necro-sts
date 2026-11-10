shader_type spatial;
// 바닥 표시 판: 2D 캔버스 그림을 그대로 입힌다. 벽에 가리되 깊이는 쓰지 않아서 몸을 가리지 않는다.
// 알파가 1보다 조금 작은 표시(탈출 지점, 출구)는 지형처럼 시야로 어둡고 밝아진다. 예고 표시는 늘 원래 색이다.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled;

#include "res://view_3d/sight.gdshaderinc"

uniform sampler2D marks : filter_nearest, repeat_disable;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 color = texture(marks, UV);
	if (color.a > 0.0 && color.a < 0.998) {
		vec3 dim = srgb_to_linear(color.rgb * terrain_dark);
		EMISSION = dim;
		ALBEDO = srgb_to_linear(color.rgb) - dim;
		ALPHA = 1.0;
	} else {
		ALBEDO = vec3(0.0);
		EMISSION = srgb_to_linear(color.rgb);
		ALPHA = color.a;
	}
}

void light() {
	if (dot(NORMAL, LIGHT) > 0.0) {
		DIFFUSE_LIGHT += vec3(sight_value(LIGHT_COLOR, world_position.xz) * ATTENUATION);
	}
}
