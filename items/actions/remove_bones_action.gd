class_name RemoveBonesAction
extends ItemAction
## 뼈 제거: 해제된 머리뼈에 들어 있는 뼈(지금 체력만큼)를 인벤토리로 돌려받는다 (UndeadRoster.remove_bones).
## 머리뼈는 처음 소환 전 상태가 되고, 다시 쓰려면 처음 소환 비용을 낸다. 뼈는 사라지거나 소모되지 않는다.
## 쓸 수 있을 때는 항목 이름에 돌려받을 개수를 붙인다 ("뼈 제거 (3개)").

## 돌려받는 뼈 아이템
@export var bone_item: ItemData
## 쓸 수 있을 때의 항목 이름. %d에 돌려받을 개수가 들어간다
@export var label_with_count_format: String = "뼈 제거 (%d개)"
@export var summoned_reason: String = "소환 중"
@export var empty_reason: String = "뼈 없음"
@export var full_reason: String = "인벤토리 가득 참"
@export var unknown_reason: String = "뺄 수 없음"


func get_state(context: ItemActionContext) -> ItemActionState:
	if context.roster == null or bone_item == null:
		return ItemActionState.unavailable(unknown_reason)
	var skull: Skull = context.get_skull()
	match context.roster.check_remove_bones(skull, bone_item):
		UndeadRoster.Result.OK:
			var state: ItemActionState = ItemActionState.available()
			state.label = label_with_count_format % context.roster.get_stored_bones(skull)
			return state
		UndeadRoster.Result.SUMMONED:
			return ItemActionState.unavailable(summoned_reason)
		UndeadRoster.Result.NOT_AWAKENED, UndeadRoster.Result.NO_BONES:
			return ItemActionState.unavailable(empty_reason)
		UndeadRoster.Result.INVENTORY_FULL:
			return ItemActionState.unavailable(full_reason)
	return ItemActionState.unavailable(unknown_reason)


func execute(context: ItemActionContext) -> bool:
	if context.roster == null or bone_item == null:
		return false
	return context.roster.remove_bones(context.get_skull(), bone_item) == UndeadRoster.Result.OK
