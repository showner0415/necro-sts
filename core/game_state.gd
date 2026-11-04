extends Node
## 오토로드 GameState: 지역 씬이 바뀌거나 다시 불러와도 유지되는 게임 전역 상태.
## 지금은 네크로맨서의 인벤토리만 가진다. 지역 씬은 시작할 때 여기서 인벤토리를 받아 쓴다.

@export var inventory_data: InventoryData

var inventory: Inventory


func _ready() -> void:
	inventory = Inventory.new(inventory_data.slot_count)


## 임시 처리: 네크로맨서가 죽어 지역을 다시 시작할 때 인벤토리를 비운다.
## 죽었을 때 무엇을 잃는지는 아직 미정이다 (docs/game-design.md). 정해지면 여기를 바꾼다.
func reset_after_death() -> void:
	inventory.clear()
