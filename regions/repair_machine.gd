class_name RepairMachine
extends InteractZone
## 거점의 수리 기계. 네크로맨서가 가까이에서 F를 누르면 interacted로 알리고, 지역 씬이 수리 창(RepairScreen)을 연다.
## 판정 영역(radius) 안에 있는 동안만 수리 창이 열려 있는다.
## 비용(무엇을 몇 개 써서 내구도를 얼마나 채우는지)은 이 노드의 값으로 둔다. 지금은 뼈 1개 = 내구도 1 (임시).

## 수리에 쓰는 아이템 (지금은 뼈)
@export var cost_item: ItemData
## 비용 아이템 1개당 채우는 내구도 (임시값)
@export var durability_per_item: float = 1.0

@export_group("임시 도형")
## 기계 그림의 크기 (기준점은 바닥 가운데)
@export var box_size: Vector2 = Vector2(20, 22)
@export var box_color: Color = Color(0.3529412, 0.4117647, 0.53333336, 1)
## 윗부분 (창고 상자의 뚜껑과 같은 방식으로 그린다)
@export var top_color: Color = Color(0.99607843, 0.68235296, 0.20392157, 1)
@export var top_height: float = 5.0


func get_prompt_label() -> String:
	return "수리 기계"


## 이 기계의 수리 규칙을 만든다. inventory는 네크로맨서의 인벤토리, roster는 소환 상태.
func make_repair(inventory: Inventory, roster: UndeadRoster) -> SkullRepair:
	return SkullRepair.new(inventory, roster, cost_item.id, durability_per_item)


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형: 몸통과 윗부분.
	draw_rect(Rect2(Vector2(-box_size.x / 2.0, -box_size.y), box_size), box_color)
	draw_rect(Rect2(Vector2(-box_size.x / 2.0, -box_size.y), Vector2(box_size.x, top_height)), top_color)
