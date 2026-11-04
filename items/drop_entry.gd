class_name DropEntry
extends Resource
## 몬스터 드랍 목록의 한 줄: 어떤 아이템을, 몇 개, 어떤 확률로 떨어뜨리는지.

@export var item: ItemData
@export var count: int = 1
## 떨어뜨릴 확률 (0~1). 1이면 항상, 0이면 절대 떨어뜨리지 않는다.
@export_range(0.0, 1.0) var chance: float = 1.0
