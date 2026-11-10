shader_type spatial;
// 시제품 지형: 정점 색 그대로 칠하고, 빛은 입사각 없이 밝기만 더한다 (바닥에 비스듬히 닿아도 멀리까지 밝게).
// 여러 빛은 더하지 않고 큰 값을 쓴다 (부채꼴과 둘레 원이 겹쳐도 원래 색보다 밝아지지 않게).
render_mode specular_disabled, cull_back;

// 앞벽 처리: 자리마다 화면 위치(xy), 반지름(z, 화면 픽셀), 세기(w, 0~1). 월드 위치는 앞벽(카메라 쪽 벽)인지 가릴 때 쓴다.
// 잘라내기 자리(플레이어, 조준점)와 반투명 자리(시야에 보이는 물체). 세기가 서서히 바뀌어 깜빡이지 않는다.
const int CUT_ZONES = 2;
const int SEE_ZONES = 16;
uniform vec4 cut_zones[CUT_ZONES];
uniform vec2 cut_world[CUT_ZONES];
uniform vec4 see_zones[SEE_ZONES];
uniform vec2 see_world[SEE_ZONES];
uniform vec2 toward_camera = vec2(0.0, 1.0);
uniform float cut_keep_height = 0.2;
uniform float see_through_strength = 0.5;

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

// 이 벽 조각이 자리 앞(카메라 쪽)이고 화면에서 자리 가까이 있으면 세기를 돌려준다. 가장자리는 부드럽게 줄어든다.
float zone_strength(vec4 zone, vec2 zone_world, vec2 frag, vec2 ground) {
	if (zone.w <= 0.0 || dot(ground - zone_world, toward_camera) <= 0.0) {
		return 0.0;
	}
	return zone.w * (1.0 - smoothstep(0.7, 1.0, length(frag - zone.xy) / zone.z));
}

// 4×4 무늬의 문턱값 (0~1). 세기가 커질수록 빠지는 픽셀이 조금씩 늘어나 부드럽게 바뀐다.
float dither(vec2 frag) {
	const float PATTERN[16] = float[16](0.03125, 0.53125, 0.15625, 0.65625, 0.78125, 0.28125, 0.90625, 0.40625, 0.21875, 0.71875, 0.09375, 0.59375, 0.96875, 0.46875, 0.84375, 0.34375);
	ivec2 pixel = ivec2(frag) % 4;
	return PATTERN[pixel.y * 4 + pixel.x];
}

void fragment() {
	ALBEDO = COLOR.rgb;
	if (world_position.y > cut_keep_height) {
		float cut = 0.0;
		float see = 0.0;
		for (int i = 0; i < CUT_ZONES; i++) {
			cut = max(cut, zone_strength(cut_zones[i], cut_world[i], FRAGCOORD.xy, world_position.xz));
		}
		for (int i = 0; i < SEE_ZONES; i++) {
			see = max(see, zone_strength(see_zones[i], see_world[i], FRAGCOORD.xy, world_position.xz));
		}
		if (max(cut, see * see_through_strength) > dither(FRAGCOORD.xy)) {
			discard;
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
