shader_type spatial;
// 3D 지형: 정점 색(sRGB) 그대로 칠한다. 빛은 시야 단계에서 넣는다.
// 앞벽 처리: 플레이어와 조준점 앞의 벽은 잘라내고, 시야에 보이는 물체 앞의 벽은 반투명하다. 세기는 FrontWalls가 서서히 바꿔 넣는다.
render_mode unshaded, cull_back;

// 잘라내기 자리: 화면 위치(xy), 반지름(z, 화면 픽셀), 세기(w, 0~1). 월드 위치는 앞벽(카메라 쪽 벽)인지 가릴 때 쓴다.
// 반투명 자리: 그림의 화면 사각형 가운데(xy)와 반폭(zw, 화면 픽셀). 세기는 see_weights
const int CUT_ZONES = 2;
const int SEE_ZONES = 16;
uniform vec4 cut_zones[CUT_ZONES];
uniform vec2 cut_world[CUT_ZONES];
uniform vec4 see_zones[SEE_ZONES];
uniform vec2 see_world[SEE_ZONES];
uniform float see_weights[SEE_ZONES];
// 그림 사각형 바깥으로 부드럽게 줄어드는 폭 (화면 픽셀)
uniform float see_feather = 4.0;
// 벽이 물체 그림을 실제로 가리려면 물체보다 이만큼 카메라 쪽에 있어야 한다 (칸. 그림의 깊이를 당긴 양만큼)
uniform float see_min_front = 0.15;
uniform vec2 toward_camera = vec2(0.0, 1.0);
// 이 높이 아래는 잘라내지 않는다 (칸)
uniform float cut_keep_height = 0.2;
uniform float see_through_strength = 0.5;

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

// 이 벽 조각이 물체 앞(카메라 쪽)이고 화면에서 물체 그림의 사각형과 겹치면 세기를 돌려준다.
float see_strength(vec4 rect, float weight, vec2 zone_world, vec2 frag, vec2 ground) {
	if (weight <= 0.0 || dot(ground - zone_world, toward_camera) <= see_min_front) {
		return 0.0;
	}
	vec2 outside = max(abs(frag - rect.xy) - rect.zw, vec2(0.0));
	return weight * (1.0 - smoothstep(0.0, see_feather, length(outside)));
}

// 4×4 무늬의 문턱값 (0~1). 세기가 커질수록 빠지는 픽셀이 조금씩 늘어나 부드럽게 바뀐다.
float dither(vec2 frag) {
	const float PATTERN[16] = float[16](0.03125, 0.53125, 0.15625, 0.65625, 0.78125, 0.28125, 0.90625, 0.40625, 0.21875, 0.71875, 0.09375, 0.59375, 0.96875, 0.46875, 0.84375, 0.34375);
	ivec2 pixel = ivec2(frag) % 4;
	return PATTERN[pixel.y * 4 + pixel.x];
}

vec3 srgb_to_linear(vec3 color) {
	return mix(pow((color + vec3(0.055)) / 1.055, vec3(2.4)), color / 12.92, lessThan(color, vec3(0.04045)));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	if (world_position.y > cut_keep_height) {
		float cut = 0.0;
		float see = 0.0;
		for (int i = 0; i < CUT_ZONES; i++) {
			cut = max(cut, zone_strength(cut_zones[i], cut_world[i], FRAGCOORD.xy, world_position.xz));
		}
		for (int i = 0; i < SEE_ZONES; i++) {
			see = max(see, see_strength(see_zones[i], see_weights[i], see_world[i], FRAGCOORD.xy, world_position.xz));
		}
		if (max(cut, see * see_through_strength) > dither(FRAGCOORD.xy)) {
			discard;
		}
	}
}
