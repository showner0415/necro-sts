extends Node
## 오토로드 GameState: 지역 씬이 바뀌거나 다시 불러와도 유지되는 게임 전역 상태.
## 네크로맨서의 인벤토리·핫바와 거점 창고를 가진다. 지역 씬은 시작할 때 여기서 받아 쓴다.

@export var inventory_data: InventoryData
## 거점 창고 설정 (칸 수)
@export var storage_data: InventoryData

var inventory: Inventory
var hotbar: Hotbar
## 거점 창고. 죽어도 비우지 않는다.
var storage: Inventory


func _ready() -> void:
	inventory = Inventory.new(inventory_data.slot_count)
	inventory.display_name = inventory_data.display_name
	hotbar = Hotbar.new(inventory_data.hotbar_slot_count, inventory)
	storage = Inventory.new(storage_data.slot_count)
	storage.display_name = storage_data.display_name


## 네크로맨서가 지역에서 죽으면 인벤토리의 물건을 전부 잃는다 (설계 확정). 창고는 비우지 않는다.
## 핫바는 인벤토리에 없는 머리뼈를 가리키지 않으므로 같이 빈다.
## 죽은 뒤 거점으로 보내는 일은 지역 씬(Region)이 한다.
func reset_after_death() -> void:
	inventory.clear()
