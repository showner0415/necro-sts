class_name ItemAction
extends Resource
## 인벤토리 칸 우클릭 메뉴의 항목 하나 (버리기, 회복하기 등).
## 아이템 데이터(ItemData.actions)에 이 리소스를 넣으면 그 아이템의 메뉴에 나온다.
## 새 항목(장착하기, 사용하기 등)은 이 클래스를 상속해 get_state()와 execute()를 채우고,
## data/item_actions/에 .tres를 만들어 아이템 데이터의 actions에 넣는다.

@export var id: StringName
## 메뉴에 보이는 이름
@export var label: String


## 이 칸의 메뉴에 이 항목을 넣을지. 기본은 네크로맨서의 인벤토리 칸에서만 (창고 칸에서는 숨김).
func is_visible_in(context: ItemActionContext) -> bool:
	return context.is_in_inventory()


## 지금 이 항목을 쓸 수 있는지, 못 쓰면 이유, 쓰면 무슨 일이 생기는지 경고.
func get_state(_context: ItemActionContext) -> ItemActionState:
	return ItemActionState.available()


## 실행한다. 실제로 무언가 했으면 true. 쓸 수 없는 상태면 아무것도 하지 않고 false.
func execute(_context: ItemActionContext) -> bool:
	return false
