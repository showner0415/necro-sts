class_name VisionRules
extends RefCounted
## 플레이어 시야 규칙 (화면에만 쓴다. 몬스터의 감지 규칙과는 상관없다). 노드에 의존하지 않는다.
## - 네크로맨서에서 바라보는 방향(마우스 쪽)으로 뻗은 부채꼴 안만 보인다: 방향에서 full_angle도 안은 완전히 밝고,
##   full_angle ~ total_angle도는 edge_steps단계로 나눠 점점 어두워지며, total_angle도 밖은 안 보인다
## - 네크로맨서 둘레 near_radius 안은 방향과 상관없이 보인다. view_range보다 먼 곳은 안 보인다
## - 부채꼴 안이어도 벽 타일 뒤는 안 보인다 (네크로맨서에서 그 칸까지 선이 지나는 타일 중 마지막 칸 앞에 벽이 있으면 가려짐)
## 결과는 칸마다 단계 번호다: 0 = 완전히 보임, 1..edge_steps = 가장자리 단계, hidden_level() = 안 보임.

## 완전히 밝은 범위: 바라보는 방향에서 좌우 이 각도 (도)
var full_angle: float = 23.0
## 보이는 범위 전체: 바라보는 방향에서 좌우 이 각도 (도). full_angle ~ total_angle이 가장자리다
var total_angle: float = 35.0
## 가장자리를 나누는 단계 수
var edge_steps: int = 2
## 방향과 상관없이 보이는 둘레 반지름 (픽셀)
var near_radius: float = 48.0
## 보이는 가장 먼 거리 (픽셀)
var view_range: float = 2000.0

## 벽 타일 격자 (set_walls). 비어 있으면 가리는 것이 없다
var _walls: PackedByteArray = PackedByteArray()
var _wall_size: Vector2i = Vector2i.ZERO
var _tile_size: float = 32.0
var _tile_origin: Vector2 = Vector2.ZERO


## 안 보이는 칸의 단계 번호
func hidden_level() -> int:
	return edge_steps + 1


## 벽을 생각하지 않은 단계: origin(네크로맨서)에서 facing(바라보는 방향)을 볼 때 point의 단계.
func level_for(origin: Vector2, facing: Vector2, point: Vector2) -> int:
	var offset: Vector2 = point - origin
	var distance: float = offset.length()
	if distance <= near_radius:
		return 0
	if distance > view_range or facing == Vector2.ZERO:
		return hidden_level()
	var angle: float = absf(rad_to_deg(facing.angle_to(offset)))
	if angle <= full_angle:
		return 0
	if angle > total_angle:
		return hidden_level()
	var step_width: float = (total_angle - full_angle) / edge_steps
	return clampi(1 + floori((angle - full_angle) / step_width), 1, edge_steps)


## 벽 타일 격자를 정한다 (벽은 움직이지 않으므로 한 번만). cells: 칸마다 1이면 벽, 가로 size.x칸씩 줄 순서.
## tile_size: 벽 타일 한 변 (픽셀), tile_origin: 타일 (0, 0)의 월드 위치. 격자 밖은 벽이 아니다.
func set_walls(cells: PackedByteArray, size: Vector2i, tile_size: float, tile_origin: Vector2) -> void:
	_walls = cells
	_wall_size = size
	_tile_size = tile_size
	_tile_origin = tile_origin


## 벽까지 생각한 단계 (벽은 set_walls로 정한 것). 둘레 원 안이어도 벽 뒤는 안 보인다.
func level_with_walls(origin: Vector2, facing: Vector2, point: Vector2) -> int:
	var level: int = level_for(origin, facing, point)
	if level == hidden_level() or _walls.is_empty():
		return level
	if not is_line_clear(origin, point):
		return hidden_level()
	return level


## origin에서 point까지 선이 지나는 타일 중 point가 든 타일 앞에 벽이 없는지 (point가 든 타일은 벽이어도 된다: 벽 면은 보인다).
## 타일 경계를 정확히 따라가는 격자 순회(DDA)다. 매 프레임 물체마다 부르므로 함수 호출 없이 배열을 바로 읽는다.
func is_line_clear(origin: Vector2, point: Vector2) -> bool:
	var start: Vector2 = (origin - _tile_origin) / _tile_size
	var end: Vector2 = (point - _tile_origin) / _tile_size
	var cx: int = floori(start.x)
	var cy: int = floori(start.y)
	var tx: int = floori(end.x)
	var ty: int = floori(end.y)
	var dx: float = end.x - start.x
	var dy: float = end.y - start.y
	var step_x: int = 1 if dx > 0.0 else -1
	var step_y: int = 1 if dy > 0.0 else -1
	var t_delta_x: float = INF if dx == 0.0 else absf(1.0 / dx)
	var t_delta_y: float = INF if dy == 0.0 else absf(1.0 / dy)
	var t_max_x: float = INF if dx == 0.0 else ((cx + (1 if step_x > 0 else 0)) - start.x) / dx
	var t_max_y: float = INF if dy == 0.0 else ((cy + (1 if step_y > 0 else 0)) - start.y) / dy
	var width: int = _wall_size.x
	var height: int = _wall_size.y
	# 지나는 타일 수는 두 칸 사이 가로·세로 차이의 합을 넘지 않는다.
	var guard: int = absi(tx - cx) + absi(ty - cy) + 2
	while (cx != tx or cy != ty) and guard > 0:
		guard -= 1
		if t_max_x < t_max_y:
			cx += step_x
			t_max_x += t_delta_x
		else:
			cy += step_y
			t_max_y += t_delta_y
		if (cx != tx or cy != ty) and cx >= 0 and cy >= 0 and cx < width and cy < height and _walls[cy * width + cx] != 0:
			return false
	return true
