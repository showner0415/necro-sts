shader_type spatial;
// 몸 그림: 화면에는 카메라를 정면으로 보는 사각형으로, 그림 1픽셀 = 화면 1픽셀로 그린다 (원근에서도 기울거나 늘어나지 않는다).
// 앞뒤 판정(깊이)은 발밑에 수직으로 세운 판의 값을 쓴다. 그래서 뒤쪽 벽에 머리가 파묻히지 않고, 앞쪽 벽에는 그대로 가린다.
// 색은 2D와 같게 sRGB 값에 tint를 곱한 뒤 선형으로 바꾼다 (임시 도형의 색, 맞았을 때 번쩍임 3배).
render_mode unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled;

uniform sampler2D sprite_texture : filter_nearest, repeat_disable;
// 그림 크기 (픽셀)와 발밑에서 그림 왼쪽 아래까지 (픽셀, 위가 +y)
uniform vec2 sprite_size = vec2(32.0);
uniform vec2 sprite_offset = vec2(-16.0, 0.0);
uniform vec4 tint = vec4(1.0);
// 깊이만 카메라 쪽으로 당기는 양 (단위). 발밑보다 아래로 그려지는 부분(꼬리 등)이 바닥에 가리지 않게 한다
uniform float depth_bias = 0.3;

void vertex() {
	vec3 feet = MODELVIEW_MATRIX[3].xyz;
	// 발밑 깊이에서 화면 1픽셀의 크기 (렌더링 방식에 따라 행렬 값이 음수일 수 있어 절댓값을 쓴다)
	float per_pixel = -2.0 * feet.z / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	vec2 texel = sprite_offset + (VERTEX.xy + vec2(0.5)) * sprite_size;
	vec3 facing_camera = vec3(feet.xy + texel * per_pixel, feet.z);
	// 같은 화면 위치에서, 발밑에 수직으로 세운 판(카메라의 가로 방향과 세계의 위쪽이 이루는 면)까지의 점
	vec3 world_up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	vec3 plane_normal = normalize(cross(vec3(1.0, 0.0, 0.0), world_up));
	vec3 on_plane = facing_camera * dot(feet, plane_normal) / dot(facing_camera, plane_normal);
	on_plane.z += depth_bias;
	vec4 clip_facing = PROJECTION_MATRIX * vec4(facing_camera, 1.0);
	vec4 clip_plane = PROJECTION_MATRIX * vec4(on_plane, 1.0);
	// 화면 위치와 w는 정면 사각형 것을 써서 그림이 왜곡되지 않게 하고, 깊이만 세운 판의 값을 쓴다.
	POSITION = vec4(clip_facing.xy, clip_plane.z / clip_plane.w * clip_facing.w, clip_facing.w);
}

vec3 srgb_to_linear(vec3 color) {
	return mix(pow((color + vec3(0.055)) / 1.055, vec3(2.4)), color / 12.92, lessThan(color, vec3(0.04045)));
}

void fragment() {
	vec4 color = texture(sprite_texture, UV) * tint;
	ALBEDO = srgb_to_linear(clamp(color.rgb, 0.0, 1.0));
	ALPHA = color.a;
}
