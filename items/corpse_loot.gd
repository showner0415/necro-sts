class_name CorpseLoot
extends RefCounted
## 시체 하나에 남은 아이템과 채집 규칙. 노드에 의존하지 않는다.
## - 몬스터가 죽을 때 드랍 확률을 굴려 정해진 것만 담는다 (머리뼈 확률도 이때 정해진다)
## - 채집 한 번에 한 묶음(뼈 N개 또는 머리뼈 하나)을 꺼낸다. 무엇을 꺼낼지는 인벤토리에 넣을 수 있는 것 중에서 무작위다
## - 채집 시간 = 몬스터의 기본 시간 × 아이템 종류의 배율

## 이 시체의 채집 기본 시간 (초). 몬스터 데이터의 harvest_base_time.
var base_time: float
var _stacks: Array[ItemStack] = []


func _init(stacks: Array[ItemStack], base_harvest_time: float) -> void:
	_stacks = stacks.duplicate()
	base_time = base_harvest_time


## 드랍 목록의 줄을 시체에 담을 묶음으로 바꾼다. 머리뼈는 하나하나 따로라 개수만큼 따로 담는다.
static func from_drops(entries: Array[DropEntry], base_harvest_time: float) -> CorpseLoot:
	var stacks: Array[ItemStack] = []
	for entry: DropEntry in entries:
		if entry.item is SkullData:
			for i: int in entry.count:
				stacks.append(ItemStack.of_skull(Skull.create(entry.item)))
		else:
			stacks.append(ItemStack.of_item(entry.item, entry.count))
	return CorpseLoot.new(stacks, base_harvest_time)


func is_empty() -> bool:
	return _stacks.is_empty()


## 남은 묶음들 (복사본)
func get_stacks() -> Array[ItemStack]:
	return _stacks.duplicate()


## 지금 인벤토리에 넣을 수 있는 묶음 중 무작위로 하나. 넣을 수 있는 것이 없으면 null.
## rng를 주면 그것으로 고르고(테스트에서 시드 고정용), 없으면 전역 난수(randi)를 쓴다.
func pick_harvestable(inventory: Inventory, rng: RandomNumberGenerator = null) -> ItemStack:
	var candidates: Array[ItemStack] = _stacks.filter(func(stack: ItemStack) -> bool: return inventory.can_add(stack))
	if candidates.is_empty():
		return null
	var index: int = rng.randi_range(0, candidates.size() - 1) if rng != null else randi() % candidates.size()
	return candidates[index]


func can_harvest(inventory: Inventory) -> bool:
	return _stacks.any(func(stack: ItemStack) -> bool: return inventory.can_add(stack))


## stack을 채집하는 데 걸리는 시간 (초)
func get_harvest_time(stack: ItemStack) -> float:
	return base_time * stack.item.harvest_time_multiplier


## stack을 인벤토리에 넣고 시체에서 뺀다. 이 시체에 없거나 인벤토리에 자리가 없으면 그대로 남기고 false.
func take(stack: ItemStack, inventory: Inventory) -> bool:
	if not _stacks.has(stack) or not inventory.try_add(stack):
		return false
	_stacks.erase(stack)
	return true
