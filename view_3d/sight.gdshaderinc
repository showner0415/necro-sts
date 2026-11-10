// 시야 빛의 공통 계산. 지형과 바닥 표시 셰이더가 쓴다. 값은 SightLights가 프레임마다 넣는다.
// 빛마다 번호가 있고(0 = 플레이어, 1부터 언데드) light_color의 r:g 비율에 번호를 담아 light()에서 알아낸다.
// 부채꼴과 둘레 원은 2D 규칙(VisionRules)과 같게 여기서 계산하고, 3D 빛은 벽 그림자만 맡는다.

const int MAX_SIGHTS = 9;
uniform vec2 sight_origin[MAX_SIGHTS];
uniform vec2 sight_facing[MAX_SIGHTS];
// 완전히 밝은 각도, 전체 각도 (도), 보는 거리, 가장자리 폭 (칸)
uniform vec4 sight_shape[MAX_SIGHTS];
// 둘레 원 반지름, 바깥 폭 (칸). 반지름 0이면 없다
uniform vec2 sight_near[MAX_SIGHTS];
// 이 빛이 어두운 색과 원래 색 사이를 얼마나 채우는지 (1 = 원래 색)
uniform float sight_energy[MAX_SIGHTS];
// 빛 없는 지형의 밝기 (sRGB 색에 곱한다). 시야가 없으면 1
uniform float terrain_dark = 1.0;

vec3 srgb_to_linear(vec3 color) {
	return mix(pow((color + vec3(0.055)) / 1.055, vec3(2.4)), color / 12.92, lessThan(color, vec3(0.04045)));
}

// 이 빛이 이 바닥 점을 밝히는 양. 그림자는 ATTENUATION을 곱해서 넣는다.
float sight_value(vec3 light_color, vec2 point) {
	int index = int(round(light_color.g / max(light_color.r, 0.0001) * float(MAX_SIGHTS))) - 1;
	if (index < 0 || index >= MAX_SIGHTS) {
		return 0.0;
	}
	vec2 to_point = point - sight_origin[index];
	float dist = length(to_point);
	vec4 shape = sight_shape[index];
	float fan = 0.0;
	if (dist > 0.0001) {
		float angle = degrees(acos(clamp(dot(to_point / dist, sight_facing[index]), -1.0, 1.0)));
		fan = 1.0 - smoothstep(shape.x, shape.y, angle);
	}
	fan *= 1.0 - smoothstep(shape.z - shape.w, shape.z, dist);
	vec2 near = sight_near[index];
	float around = near.x > 0.0 ? 1.0 - smoothstep(near.x, near.x + near.y, dist) : 0.0;
	return max(fan, around) * sight_energy[index];
}
