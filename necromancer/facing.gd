class_name Facing
extends RefCounted
## 방향을 N방향 그림 번호로 바꾸는 규칙.
## 0번이 동쪽이고, 화면에서 시계 방향으로 번호가 커진다 (y가 아래로 커지므로 1번이 남동, 2번이 남).
## 두 방향의 딱 가운데(예: 8방향에서 22.5도)는 번호가 큰 쪽으로 간다.


## direction이 영(0) 벡터면 0번(동쪽)을 돌려준다. 멈춘 채 방향을 유지하려면 부르는 쪽에서 거른다.
static func index_for(direction: Vector2, count: int) -> int:
	var step: float = TAU / count
	return wrapi(roundi(direction.angle() / step), 0, count)
