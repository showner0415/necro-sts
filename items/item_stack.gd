class_name ItemStack
extends RefCounted
## 인벤토리 칸 하나, 또는 바닥 더미 하나에 든 물건.
## - 뼈 같은 아이템: item을 count개 (한 칸에 개수 제한 없이 쌓인다)
## - 머리뼈: skull 하나 (item은 그 머리뼈의 종류, count는 1). 하나하나 따로라 합쳐지지 않는다.

var item: ItemData
var count: int = 0
var skull: Skull


static func of_item(item_data: ItemData, amount: int) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	stack.item = item_data
	stack.count = amount
	return stack


static func of_skull(skull_value: Skull) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	stack.item = skull_value.data
	stack.count = 1
	stack.skull = skull_value
	return stack


func is_skull() -> bool:
	return skull != null


func get_display_name() -> String:
	return skull.get_display_name() if is_skull() else item.display_name


## other를 이 칸에 합칠 수 있는지: 둘 다 머리뼈가 아니고 같은 종류일 때
func can_merge(other: ItemStack) -> bool:
	return not is_skull() and not other.is_skull() and item.id == other.item.id
