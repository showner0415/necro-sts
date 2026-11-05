class_name ItemTransfer
extends RefCounted
## 인벤토리와 창고 사이(그리고 한쪽 안에서) 물건을 옮기는 규칙.
## - 끌어 놓기(move): 빈 칸이면 옮기기, 같은 종류의 뼈 칸이면 합치기, 아니면 자리 바꾸기
## - 보내기(send, 메뉴의 "옮기기"): 받는 쪽의 같은 종류 뼈 칸에 합치고, 없으면 가장 앞의 빈 칸. 자리가 없으면 FULL
## - 소환 중인 머리뼈는 네크로맨서의 인벤토리 밖(창고)으로 나갈 수 없다 (자리 바꾸기로 밀려나는 경우도 포함)
## 핫바는 인벤토리에 없는 머리뼈를 가리키지 않으므로, 머리뼈를 창고로 옮기면 그 핫바 칸은 저절로 빈다.
## 노드에 의존하지 않으므로 씬 없이 확인할 수 있다.

enum Result {
	OK,
	## 옮길 물건이 없거나 칸 번호가 범위 밖
	INVALID,
	## 소환 중인 머리뼈가 인벤토리 밖으로 나가게 됨
	SUMMONED,
	## 받는 쪽에 자리가 없음 (보내기)
	FULL,
}

## 네크로맨서의 인벤토리. 소환 중인 머리뼈는 여기서 나갈 수 없다.
var inventory: Inventory
## 소환 상태. 없으면 소환 중 검사를 하지 않는다.
var roster: UndeadRoster


func _init(player_inventory: Inventory, undead_roster: UndeadRoster) -> void:
	inventory = player_inventory
	roster = undead_roster


func check_move(from: Inventory, from_index: int, to: Inventory, to_index: int) -> Result:
	var moving: ItemStack = from.get_slot(from_index)
	if moving == null or to_index < 0 or to_index >= to.get_slot_count():
		return Result.INVALID
	if from == to:
		return Result.OK
	var target: ItemStack = to.get_slot(to_index)
	# 인벤토리 → 창고로 나가는 것: 옮기는 물건
	if from == inventory and _is_summoned(moving):
		return Result.SUMMONED
	# 창고 → 인벤토리로 들어오며 자리 바꾸기로 밀려나는 것: 인벤토리 칸에 있던 물건
	if to == inventory and target != null and not target.can_merge(moving) and _is_summoned(target):
		return Result.SUMMONED
	return Result.OK


func move(from: Inventory, from_index: int, to: Inventory, to_index: int) -> Result:
	var check: Result = check_move(from, from_index, to, to_index)
	if check != Result.OK:
		return check
	Inventory.transfer(from, from_index, to, to_index)
	return Result.OK


func check_send(from: Inventory, from_index: int, to: Inventory) -> Result:
	var moving: ItemStack = from.get_slot(from_index)
	if moving == null or from == to:
		return Result.INVALID
	if from == inventory and _is_summoned(moving):
		return Result.SUMMONED
	if not to.can_add(moving):
		return Result.FULL
	return Result.OK


func send(from: Inventory, from_index: int, to: Inventory) -> Result:
	var check: Result = check_send(from, from_index, to)
	if check != Result.OK:
		return check
	var stack: ItemStack = from.remove_slot(from_index)
	to.try_add(stack)
	return Result.OK


func _is_summoned(stack: ItemStack) -> bool:
	return roster != null and stack.is_skull() and roster.is_summoned(stack.skull)
