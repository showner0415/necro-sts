class_name ItemActionContext
extends RefCounted
## 메뉴 항목이 무엇을 대상으로, 무엇을 써서 실행되는지 모아 둔 것.
## 노드가 아니므로 씬 없이 만들어 테스트할 수 있다.

## 네크로맨서의 인벤토리
var inventory: Inventory
## 메뉴를 연 칸이 들어 있는 곳 (인벤토리 또는 창고). 비워 두면 inventory.
var container: Inventory
## 지금 열려 있는 창고. 창고가 열려 있지 않으면 null.
var storage: Inventory
var hotbar: Hotbar
## 머리뼈의 소환 상태·회복 규칙. 없으면 null.
var roster: UndeadRoster
## 인벤토리 ↔ 창고 옮기기 규칙. 창고가 없으면 null.
var transfer: ItemTransfer
## 메뉴를 연 칸 번호 (container 안에서)
var slot_index: int = -1
## func(stack: ItemStack) -> void. 꺼낸 물건을 바닥(네크로맨서 발밑)에 놓는다.
var drop_to_ground: Callable


## 메뉴를 연 칸이 네크로맨서의 인벤토리에 있는지
func is_in_inventory() -> bool:
	return get_container() == inventory


func get_container() -> Inventory:
	return container if container != null else inventory


## 메뉴를 연 칸의 물건 (그 사이 비었으면 null)
func get_stack() -> ItemStack:
	return get_container().get_slot(slot_index)


## 메뉴를 연 칸의 머리뼈 (머리뼈가 아니면 null)
func get_skull() -> Skull:
	# ItemData → ItemAction → 이 클래스 → Inventory → ItemStack → ItemData로 스크립트가 서로 물려 있어서,
	# 타입을 붙여 받으면 Godot가 반환 타입을 잘못 읽는다 (Array로 읽음). 그래서 Variant로 받는다.
	var stack: Variant = get_container().get_slot(slot_index)
	if stack == null:
		return null
	return (stack as ItemStack).skull
