class_name InventoryData
extends Resource
## 인벤토리·핫바 설정. 칸 수를 늘릴 때는 이 데이터만 바꾼다.

@export var id: StringName
@export var slot_count: int = 10
## 머리뼈 바로가기(핫바) 칸 수
@export var hotbar_slot_count: int = 2
