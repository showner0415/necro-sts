class_name Hotbar
extends RefCounted
## 머리뼈 바로가기 칸. 칸마다 인벤토리 안의 머리뼈 하나를 가리키거나 비어 있다(null).
## - 칸 번호가 아니라 머리뼈 자체(Skull)를 가리키므로, 인벤토리에서 칸을 옮겨도 같은 머리뼈를 가리킨다
## - 가리키던 머리뼈가 인벤토리에서 사라지면 그 칸은 빈다
## - 똑같은 머리뼈 하나는 한 칸에만 들어간다 (다른 칸에 있던 것을 놓으면 옮겨진다)
## 노드가 아니므로 씬 없이 만들어 쓰고 확인할 수 있다. 게임에서는 GameState가 하나 가진다.
## 칸 내용이 바뀌면 changed로 알린다.

signal changed
## 선택된 칸이 바뀌면 알린다 (숫자키)
signal selection_changed(index: int)

## 선택된 칸 번호. 소환(G)·회복(R)은 이 칸의 머리뼈에 한다.
var selected_index: int = 0
var _inventory: Inventory
var _skulls: Array[Skull] = []


func _init(slot_count: int, inventory: Inventory) -> void:
	_skulls.resize(slot_count)
	_inventory = inventory
	_inventory.changed.connect(_on_inventory_changed)


func get_slot_count() -> int:
	return _skulls.size()


## 그 칸이 가리키는 머리뼈. 비어 있거나 범위 밖이면 null.
func get_skull(index: int) -> Skull:
	if not _is_valid_index(index):
		return null
	return _skulls[index]


## 그 칸을 선택한다. 범위 밖이면 false.
func select(index: int) -> bool:
	if not _is_valid_index(index):
		return false
	if selected_index != index:
		selected_index = index
		selection_changed.emit(index)
	return true


func get_selected_skull() -> Skull:
	return get_skull(selected_index)


## 가장 앞의 빈 칸 번호. 없으면 -1.
func find_empty_slot() -> int:
	return _skulls.find(null)


## skull이 들어 있는 칸 번호. 없으면 -1.
func find_slot(skull: Skull) -> int:
	if skull == null:
		return -1
	return _skulls.find(skull)


## 그 칸이 skull을 가리키게 한다. 이미 차 있으면 새 머리뼈로 바뀐다.
## skull이 다른 칸에 있었으면 그 칸은 빈다. 인벤토리에 없는 머리뼈는 놓을 수 없다(false).
func assign(index: int, skull: Skull) -> bool:
	if not _is_valid_index(index) or skull == null or not _inventory.get_skulls().has(skull):
		return false
	var previous_index: int = _skulls.find(skull)
	if previous_index == index:
		return true
	if previous_index != -1:
		_skulls[previous_index] = null
	_skulls[index] = skull
	changed.emit()
	return true


## 그 칸만 비운다. 머리뼈는 인벤토리에 그대로 있다.
func clear_slot(index: int) -> bool:
	if get_skull(index) == null:
		return false
	_skulls[index] = null
	changed.emit()
	return true


## 두 칸이 가리키는 머리뼈를 바꾼다. 한쪽이 비어 있으면 옮기기가 된다.
func swap(a: int, b: int) -> bool:
	if not _is_valid_index(a) or not _is_valid_index(b):
		return false
	if a == b:
		return true
	var temp: Skull = _skulls[a]
	_skulls[a] = _skulls[b]
	_skulls[b] = temp
	changed.emit()
	return true


func _on_inventory_changed() -> void:
	var owned: Array[Skull] = _inventory.get_skulls()
	var cleared: bool = false
	for i: int in _skulls.size():
		if _skulls[i] != null and not owned.has(_skulls[i]):
			_skulls[i] = null
			cleared = true
	if cleared:
		changed.emit()


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _skulls.size()
