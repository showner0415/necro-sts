class_name AimLead
extends RefCounted
## 카메라가 조준 방향으로 앞서 가는 양 (화면 픽셀). 노드에 의존하지 않는다.
## - 마우스의 화면 위치로만 계산한다. 카메라가 움직여도 입력이 바뀌지 않으므로 되먹임이 없다
## - 플레이어와 마우스 사이 거리의 ratio만큼 움직인다. 카메라가 움직이면 플레이어가 반대쪽으로 밀려나므로 거리는 (화면 가운데에서 마우스까지 + 움직인 양)이다.
##   그 거리의 ratio가 움직인 양이 되도록 풀면, 움직인 양 = 화면 가운데에서 마우스까지 × ratio / (1 - ratio)
## - 마우스가 가운데에서 dead_zone 안이면 움직이지 않는다. 경계에서 튀지 않게 dead_zone을 뺀 거리로 계산한다
## - 움직이는 양은 max_distance를 넘지 않는다 (플레이어가 화면 가장자리로 밀려나지 않게)
## - strength: 전체 세기. 나중에 설정에서 0까지 줄일 수 있다 (0이면 카메라가 플레이어만 따라간다)

const MAX_RATIO: float = 0.9

## 플레이어와 마우스 사이 거리 중 카메라가 움직이는 비율 (사용자 값)
var ratio: float = 0.3
## 카메라가 움직이는 최대 거리 (화면 픽셀, 제안값). 화면 세로 반이 180이다
var max_distance: float = 90.0
## 움직이지 않는 구역의 반지름 (화면 픽셀, 제안값)
var dead_zone: float = 32.0
## 따라가는 빠르기 (초당, 제안값). 클수록 빨리 따라간다
var follow_speed: float = 6.0
## 전체 세기 (0~1)
var strength: float = 1.0


## 마우스가 screen_position일 때 카메라가 움직일 양 (화면 픽셀)
func target_offset(mouse: Vector2, screen_center: Vector2) -> Vector2:
	var from_center: Vector2 = mouse - screen_center
	var distance: float = from_center.length()
	if distance <= dead_zone or distance == 0.0:
		return Vector2.ZERO
	var clamped_ratio: float = clampf(ratio, 0.0, MAX_RATIO)
	var effective: Vector2 = from_center * ((distance - dead_zone) / distance)
	return (effective * clamped_ratio / (1.0 - clamped_ratio)).limit_length(max_distance) * clampf(strength, 0.0, 1.0)


## 지금 값에서 목표로 부드럽게 다가간 값. 시간 간격이 달라도 같은 빠르기다.
func follow(current: Vector2, target: Vector2, delta: float) -> Vector2:
	return current.lerp(target, 1.0 - exp(-follow_speed * delta))
