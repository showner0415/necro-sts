class_name TransferItemAction
extends ItemAction
## 인벤토리 ↔ 창고 보내기. 아이템 종류와 상관없이 칸 자체에 붙는 항목이라, 아이템 데이터가 아니라
## 인벤토리 화면(InventoryScreen.container_actions)에 넣는다.
## - to_storage가 true: 창고가 열려 있을 때 인벤토리 칸에 "창고로 옮기기"
## - to_storage가 false: 창고 칸에 "인벤토리로 옮기기"
## 받는 쪽 같은 종류의 뼈 칸에 합치고, 없으면 가장 앞의 빈 칸에 넣는다 (ItemTransfer.send).

@export var to_storage: bool = true
@export var full_reason: String = "가득 참"
@export var summoned_reason: String = "소환 중"


func is_visible_in(context: ItemActionContext) -> bool:
	if context.storage == null or context.transfer == null:
		return false
	return context.is_in_inventory() if to_storage else context.get_container() == context.storage


func get_state(context: ItemActionContext) -> ItemActionState:
	match context.transfer.check_send(context.get_container(), context.slot_index, _destination(context)):
		ItemTransfer.Result.OK:
			return ItemActionState.available()
		ItemTransfer.Result.FULL:
			return ItemActionState.unavailable(full_reason)
		ItemTransfer.Result.SUMMONED:
			return ItemActionState.unavailable(summoned_reason)
	return ItemActionState.unavailable("")


func execute(context: ItemActionContext) -> bool:
	if not is_visible_in(context):
		return false
	return context.transfer.send(context.get_container(), context.slot_index, _destination(context)) == ItemTransfer.Result.OK


func _destination(context: ItemActionContext) -> Inventory:
	return context.storage if to_storage else context.inventory
