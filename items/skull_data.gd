class_name SkullData
extends ItemData
## 머리뼈 한 종류의 정의 (예: 쥐의 머리뼈). 실제로 가진 머리뼈 하나하나는 Skull이다.

## 이 머리뼈가 어떤 몬스터의 것인지 (MonsterData.id).
## 몬스터 드랍 목록이 이 리소스를 직접 참조하므로, 여기서까지 MonsterData를 직접 참조하면
## 두 .tres가 서로를 가리켜 불러오지 못한다. 그래서 id로 가리킨다.
@export var source_monster_id: StringName
## 새로 얻은 머리뼈의 내구도
@export var max_durability: float = 10.0
