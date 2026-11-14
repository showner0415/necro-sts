class_name DropEntry
extends Resource
## 몬스터 드랍 목록의 한 줄: 어떤 아이템을, 몇 개, 어떤 확률로 떨어뜨리는지.

@export var item: ItemData
## 개수 (expected_count가 0보다 크면 쓰지 않는다)
@export var count: int = 1
## 떨어뜨릴 확률 (0~1). 1이면 항상, 0이면 절대 떨어뜨리지 않는다.
@export_range(0.0, 1.0) var chance: float = 1.0
## 0보다 크면 count 대신 이 기대값으로 개수를 정한다: 정수 부분은 확정, 소수 부분은 확률로 하나 더 (예: 2.4 = 2개 + 40% 확률로 1개).
## 몬스터 뼈가 쓴다 (계획 7a, docs/game-design.md "몬스터 무리"의 드랍 줄). chance는 그 앞에 따로 굴린다
@export var expected_count: float = 0.0
