class_name DropItemAction
extends ItemAction
## 버리기: 칸의 물건을 통째로 꺼내 네크로맨서 발밑에 놓는다. 다시 주울 수 있다.
## 소환 중인 머리뼈를 버리면 죽은 판정이 되므로 경고를 붙인다 (판정은 UndeadRoster가 한다).

@export var summoned_warning: String = "죽은 판정이 됩니다"


func get_state(context: ItemActionContext) -> ItemActionState:
	var skull: Skull = context.get_skull()
	if skull != null and context.roster != null and context.roster.is_summoned(skull):
		return ItemActionState.available(summoned_warning)
	return ItemActionState.available()


func execute(context: ItemActionContext) -> bool:
	var stack: ItemStack = context.get_container().remove_slot(context.slot_index)
	if stack == null:
		return false
	if context.drop_to_ground.is_valid():
		context.drop_to_ground.call(stack)
	return true
