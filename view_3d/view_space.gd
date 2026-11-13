class_name ViewSpace
extends RefCounted
## 2D 규칙 세계와 3D 화면 층 사이의 좌표 규칙. 노드에 의존하지 않는다.
## - 2D (x, y) → 3D (x / TILE, 높이 / TILE, y / TILE). 타일 한 칸 = 3D 1단위
## - 2D의 조준 위치·탄은 발밑 평면에서 y로 몸 가운데 높이(offset)만큼 위쪽 자리에 있다. 3D에서는 그만큼 되돌리고,
##   화면에서 몸 그림의 가운데에 오는 높이(height)로 올린다. 둘은 다를 수 있다 (규칙의 몸 반지름과 그림 크기가 달라서)

const TILE: float = 32.0


## 월드(2D) 좌표에서 높이 height_px인 점의 3D 위치
static func to_3d(world: Vector2, height_px: float) -> Vector3:
	return Vector3(world.x / TILE, height_px / TILE, world.y / TILE)


## 조준 위치(2D)가 3D에서 있는 점: y를 offset_px만큼 되돌리고 높이 height_px의 평면 위에 놓는다
static func aim_to_3d(aim: Vector2, offset_px: float, height_px: float) -> Vector3:
	return to_3d(aim + Vector2(0, offset_px), height_px)


## 카메라가 feet를 보고 있을 때(앞서 가기 없이) 높이 height_px의 point가 화면 가운데에서 떨어진 정도 (화면 픽셀, 아래가 +y).
## 창이 없는 시나리오에서 "화면 안인지"를 내부 해상도로 잴 때 쓴다.
static func screen_offset(feet: Vector2, point: Vector2, height_px: float, pitch_degrees: float, yaw_degrees: float, fov_degrees: float, viewport_height: float) -> Vector2:
	var camera_basis: Basis = Basis.from_euler(Vector3(deg_to_rad(-pitch_degrees), deg_to_rad(yaw_degrees), 0.0))
	var half_height: float = viewport_height * 0.5
	var distance: float = (half_height / TILE) / tan(deg_to_rad(fov_degrees * 0.5))
	var eye: Vector3 = to_3d(feet, 0.0) + camera_basis.z * distance
	var in_camera: Vector3 = camera_basis.inverse() * (to_3d(point, height_px) - eye)
	var scale_factor: float = half_height / (-in_camera.z * tan(deg_to_rad(fov_degrees * 0.5)))
	return Vector2(in_camera.x, -in_camera.y) * scale_factor


## 화면 광선이 높이 height_px의 평면과 만나는 점을 조준 위치(2D, y를 offset_px만큼 위쪽)로 바꾼다. aim_to_3d의 반대. 광선이 평면과 나란하면 fallback.
static func aim_from_ray(origin: Vector3, direction: Vector3, offset_px: float, height_px: float, fallback: Vector2) -> Vector2:
	if is_zero_approx(direction.y):
		return fallback
	var hit: Vector3 = origin + direction * ((height_px / TILE - origin.y) / direction.y)
	return Vector2(hit.x, hit.z) * TILE - Vector2(0, offset_px)
