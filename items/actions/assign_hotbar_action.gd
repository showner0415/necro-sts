class_name AssignHotbarAction
extends ItemAction
## 핫바에 등록: 머리뼈를 가장 앞의 빈 핫바 칸에 놓고, 빈 칸이 없으면 선택된 핫바 칸을 바꾼다.
## 바뀐 칸의 머리뼈가 소환 중이었으면 핫바에서 빠진 것이므로 일반 해제된다 (UndeadRoster).
## 이미 핫바에 있는 머리뼈에는 이 항목 대신 "핫바에서 빼기"(UnassignHotbarAction)가 보인다.


func is_visible_in(context: ItemActionContext) -> bool:
	return super(context) and context.hotbar.find_slot(context.get_skull()) == -1


func execute(context: ItemActionContext) -> bool:
	var skull: Skull = context.get_skull()
	if skull == null or context.hotbar.find_slot(skull) != -1:
		return false
	var index: int = context.hotbar.find_empty_slot()
	if index == -1:
		index = context.hotbar.selected_index
	return context.hotbar.assign(index, skull)
