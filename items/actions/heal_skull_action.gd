class_name HealSkullAction
extends ItemAction
## 회복하기: 머리뼈의 언데드 체력을 뼈로 회복한다. 핫바 + R과 같은 규칙(UndeadRoster.heal)을 쓴다.

@export var summoned_reason: String = "소환 중"
@export var full_reason: String = "체력 가득"
@export var no_bones_reason: String = "뼈 부족"
@export var unknown_reason: String = "회복할 수 없음"


func get_state(context: ItemActionContext) -> ItemActionState:
	if context.roster == null:
		return ItemActionState.unavailable(unknown_reason)
	match context.roster.check_heal(context.get_skull()):
		UndeadRoster.Result.OK:
			return ItemActionState.available()
		UndeadRoster.Result.SUMMONED:
			return ItemActionState.unavailable(summoned_reason)
		UndeadRoster.Result.FULL_HEALTH, UndeadRoster.Result.NOT_AWAKENED:
			return ItemActionState.unavailable(full_reason)
		UndeadRoster.Result.NO_BONES:
			return ItemActionState.unavailable(no_bones_reason)
	return ItemActionState.unavailable(unknown_reason)


func execute(context: ItemActionContext) -> bool:
	if context.roster == null:
		return false
	return context.roster.heal(context.get_skull()) == UndeadRoster.Result.OK
