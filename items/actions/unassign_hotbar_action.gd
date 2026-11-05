class_name UnassignHotbarAction
extends ItemAction
## 핫바에서 빼기: 이미 핫바에 있는 머리뼈를 핫바에서만 뺀다 (핫바 칸 우클릭과 같음). 머리뼈는 인벤토리에 남는다.
## 소환 중이었으면 핫바에서 빠졌으므로 일반 해제된다 (UndeadRoster). 그래서 그때는 경고를 붙인다.

## 소환 중인 머리뼈를 뺄 때 붙이는 경고
@export var summoned_warning: String = "소환이 해제됩니다"


func is_visible_in(context: ItemActionContext) -> bool:
	return super(context) and context.hotbar.find_slot(context.get_skull()) != -1


func get_state(context: ItemActionContext) -> ItemActionState:
	if context.roster != null and context.roster.is_summoned(context.get_skull()):
		return ItemActionState.available(summoned_warning)
	return ItemActionState.available()


func execute(context: ItemActionContext) -> bool:
	var index: int = context.hotbar.find_slot(context.get_skull())
	if index == -1:
		return false
	return context.hotbar.clear_slot(index)
