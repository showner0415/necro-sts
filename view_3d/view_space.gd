class_name ViewSpace
extends RefCounted
## 2D 규칙 세계와 3D 화면 층 사이의 좌표 규칙. 노드에 의존하지 않는다.
## - 2D (x, y) → 3D (x / TILE, 높이 / TILE, y / TILE). 타일 한 칸 = 3D 1단위
## - 2D의 조준 위치는 발밑 평면에서 y로 몸 높이만큼 위쪽 자리에 있다. 3D에서는 그만큼 되돌리고 높이로 올린다

const TILE: float = 32.0


## 월드(2D) 좌표에서 높이 height_px인 점의 3D 위치
static func to_3d(world: Vector2, height_px: float) -> Vector3:
	return Vector3(world.x / TILE, height_px / TILE, world.y / TILE)


## 조준 위치(2D)가 3D에서 있는 점 (높이 aim_height_px의 평면 위)
static func aim_to_3d(aim: Vector2, aim_height_px: float) -> Vector3:
	return to_3d(aim + Vector2(0, aim_height_px), aim_height_px)


## 화면 광선이 높이 aim_height_px의 평면과 만나는 점을 조준 위치(2D)로 바꾼다. 광선이 평면과 나란하면 fallback.
static func aim_from_ray(origin: Vector3, direction: Vector3, aim_height_px: float, fallback: Vector2) -> Vector2:
	if is_zero_approx(direction.y):
		return fallback
	var hit: Vector3 = origin + direction * ((aim_height_px / TILE - origin.y) / direction.y)
	return Vector2(hit.x, hit.z) * TILE - Vector2(0, aim_height_px)
