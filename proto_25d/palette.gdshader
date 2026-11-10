shader_type canvas_item;
// 시제품: 화면의 모든 색을 팔레트(Endesga 32 + 빛 없는 지형용 어두운 단계 4개, palette_dark_steps.hex)에서 가장 가까운 색으로 바꾼다. 켜고 끄며 비교한다.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec3 palette[36];

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	vec3 best = color;
	float best_distance = 1000.0;
	for (int i = 0; i < 36; i++) {
		vec3 offset = color - palette[i];
		float distance_squared = dot(offset, offset);
		if (distance_squared < best_distance) {
			best_distance = distance_squared;
			best = palette[i];
		}
	}
	COLOR = vec4(best, 1.0);
}
