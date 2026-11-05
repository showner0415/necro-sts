class_name Inventory
extends RefCounted
## 칸 수가 정해진 인벤토리. 칸마다 ItemStack 하나가 들어 있거나 비어 있다(null).
## 물건은 들어간 칸 위치를 유지하고, 칸끼리 옮기거나 자리를 바꿀 수 있다.
## 노드가 아니므로 씬 없이 만들어 쓰고 확인할 수 있다. 게임에서는 GameState가 하나 가진다.
## 칸 내용이 바뀌면 changed로 알린다.

signal changed

var _slots: Array[ItemStack] = []


func _init(slot_count: int) -> void:
	_slots.resize(slot_count)


func get_slot_count() -> int:
	return _slots.size()


## 그 칸의 물건. 비어 있거나 범위 밖이면 null.
func get_slot(index: int) -> ItemStack:
	if not _is_valid_index(index):
		return null
	return _slots[index]


## stack을 넣을 자리가 있는지 (같은 종류 뼈 칸에 합치거나, 빈 칸이 있거나)
func can_add(stack: ItemStack) -> bool:
	return _find_merge_slot(stack) != -1 or _find_empty_slot() != -1


## 같은 종류가 있는 칸에 합치고, 없으면 가장 앞의 빈 칸에 넣는다. 넣을 자리가 없으면 false.
func try_add(stack: ItemStack) -> bool:
	var merge_index: int = _find_merge_slot(stack)
	if merge_index != -1:
		_slots[merge_index].count += stack.count
		changed.emit()
		return true
	var empty_index: int = _find_empty_slot()
	if empty_index == -1:
		return false
	_slots[empty_index] = stack
	changed.emit()
	return true


## 그 칸을 비우고 들어 있던 물건을 돌려준다. 비어 있었으면 null.
func remove_slot(index: int) -> ItemStack:
	var stack: ItemStack = get_slot(index)
	if stack == null:
		return null
	_slots[index] = null
	changed.emit()
	return stack


## from 칸의 물건을 to 칸으로 옮긴다. to가 비었으면 옮기고, 같은 종류의 뼈면 합치고, 아니면 두 칸의 자리를 바꾼다.
## from이 비었거나 범위 밖이면 아무것도 하지 않고 false.
func move_slot(from_index: int, to_index: int) -> bool:
	return Inventory.transfer(self, from_index, self, to_index)


## from 인벤토리의 칸에서 to 인벤토리의 칸으로 옮긴다 (인벤토리 ↔ 창고). 규칙은 move_slot과 같다.
## 두 쪽을 다 바꾼 뒤에 changed를 알린다. 바뀐 것이 없거나 범위 밖이면 false.
static func transfer(from: Inventory, from_index: int, to: Inventory, to_index: int) -> bool:
	if from.get_slot(from_index) == null or not to._is_valid_index(to_index):
		return false
	if from == to and from_index == to_index:
		return true
	var moving: ItemStack = from._slots[from_index]
	var target: ItemStack = to._slots[to_index]
	if target != null and target.can_merge(moving):
		target.count += moving.count
		from._slots[from_index] = null
	else:
		from._slots[from_index] = target
		to._slots[to_index] = moving
	from.changed.emit()
	if to != from:
		to.changed.emit()
	return true


## 그 종류(머리뼈 제외)를 최대 amount개 꺼내 없앤다. 다 쓴 칸은 빈다. 실제로 꺼낸 개수를 돌려준다.
## 여러 칸에 나뉘어 있으면 뒤쪽 칸부터 쓴다.
func remove_count(item_id: StringName, amount: int) -> int:
	var removed: int = 0
	for i: int in range(_slots.size() - 1, -1, -1):
		if removed >= amount:
			break
		var stack: ItemStack = _slots[i]
		if stack == null or stack.is_skull() or stack.item.id != item_id:
			continue
		var take: int = mini(stack.count, amount - removed)
		stack.count -= take
		removed += take
		if stack.count == 0:
			_slots[i] = null
	if removed > 0:
		changed.emit()
	return removed


func clear() -> void:
	_slots.fill(null)
	changed.emit()


## 그 종류(머리뼈 제외)를 모든 칸에서 합한 개수
func get_count(item_id: StringName) -> int:
	var total: int = 0
	for stack: ItemStack in _slots:
		if stack != null and not stack.is_skull() and stack.item.id == item_id:
			total += stack.count
	return total


## 가진 머리뼈를 칸 순서대로 돌려준다.
func get_skulls() -> Array[Skull]:
	var result: Array[Skull] = []
	for stack: ItemStack in _slots:
		if stack != null and stack.is_skull():
			result.append(stack.skull)
	return result


## 머리뼈 종류별 개수. 종류는 칸 순서에서 처음 나온 순서대로다.
func get_skull_counts() -> Dictionary[SkullData, int]:
	var counts: Dictionary[SkullData, int] = {}
	for skull: Skull in get_skulls():
		counts[skull.data] = counts.get(skull.data, 0) + 1
	return counts


func _find_merge_slot(stack: ItemStack) -> int:
	for i: int in _slots.size():
		if _slots[i] != null and _slots[i].can_merge(stack):
			return i
	return -1


func _find_empty_slot() -> int:
	return _slots.find(null)


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()
