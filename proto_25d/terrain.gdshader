shader_type spatial;
// 시제품 지형: 정점 색 그대로 칠하고, 빛은 입사각 없이 밝기만 더한다 (바닥에 비스듬히 닿아도 멀리까지 밝게).
// 여러 빛은 더하지 않고 큰 값을 쓴다 (부채꼴과 둘레 원이 겹쳐도 원래 색보다 밝아지지 않게).
render_mode specular_disabled, cull_back;

// 앞벽 처리: 0 끔, 1 반투명(체크 무늬로 칸을 뺌), 2 잘라내기
uniform int cut_mode = 0;
uniform vec3 cut_center = vec3(0.0);
uniform vec2 cut_half = vec2(3.0, 3.0);
uniform float cut_keep_height = 0.2;

// 시야 모양: 거리는 칸 단위, 각도는 도. 값은 View3D가 2D 시야와 같게 넣는다.
uniform vec3 sight_origin = vec3(0.0);
uniform vec2 sight_facing = vec2(1.0, 0.0);
uniform float full_angle = 23.0;
uniform float total_angle = 35.0;
uniform float near_radius = 1.5;
uniform float near_fade = 0.25;
uniform float view_range = 14.0;
uniform float view_edge = 1.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	if (cut_mode > 0 && world_position.y > cut_keep_height) {
		vec2 offset = world_position.xz - cut_center.xz;
		if (offset.y > 0.0 && length(offset / cut_half) < 1.0) {
			if (cut_mode == 2) {
				discard;
			}
			ivec2 pixel = ivec2(FRAGCOORD.xy);
			if ((pixel.x + pixel.y) % 2 == 0) {
				discard;
			}
		}
	}
}

void light() {
	if (dot(NORMAL, LIGHT) > 0.0) {
		// 시야 모양은 2D 규칙(VisionRules)과 같게 여기서 계산한다. 빛은 벽 그림자만 맡는다.
		vec2 to_point = world_position.xz - sight_origin.xz;
		float dist = length(to_point);
		float fan = 0.0;
		if (dist > 0.0001) {
			float angle = degrees(acos(clamp(dot(to_point / dist, sight_facing), -1.0, 1.0)));
			fan = 1.0 - smoothstep(full_angle, total_angle, angle);
		}
		fan *= 1.0 - smoothstep(view_range - view_edge, view_range, dist);
		float near = 1.0 - smoothstep(near_radius, near_radius + near_fade, dist);
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, max(fan, near) * ATTENUATION * LIGHT_COLOR / PI);
	}
}
