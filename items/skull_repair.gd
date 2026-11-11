class_name SkullRepair
extends RefCounted
## 머리뼈 내구도 수리 규칙 (거점의 수리 기계가 쓴다). 네크로맨서 인벤토리의 비용 아이템(지금은 뼈)을 써서 내구도를 채운다.
## - 비용 아이템 1개당 durability_per_item만큼 찬다 (지금 1. 비용은 임시이고 나중에 정한다)
## - 모자란 내구도에 드는 개수는 올림한다 (0.5가 모자라도 1개)
## - 비용 아이템이 모자라면 가진 만큼 일부 수리한다 (체력 회복과 같은 규칙)
## - 소환 중인 머리뼈는 수리할 수 없다
## - 네크로맨서의 인벤토리에 있는 머리뼈만 수리한다
## 노드에 의존하지 않으므로 씬 없이 확인할 수 있다.

enum Result {
	OK,
	## 머리뼈가 없거나 인벤토리에 없음
	NO_SKULL,
	## 소환 중
	SUMMONED,
	## 내구도가 가득 참
	FULL,
	## 비용 아이템이 하나도 없음
	NO_COST_ITEM,
}

## 내구도 계산의 오차 허용 (0.1 + 0.2 같은 소수 오차로 개수가 하나 더 나오지 않게)
const TOLERANCE: float = 0.0001

## 비용 아이템 1개당 채우는 내구도
var durability_per_item: float
## 비용 아이템의 id (지금은 뼈)
var cost_item_id: StringName
var _inventory: Inventory
## 소환 상태. 없으면 소환 중 검사를 하지 않는다.
var _roster: UndeadRoster


func _init(inventory: Inventory, roster: UndeadRoster, item_id: StringName, per_item: float) -> void:
	_inventory = inventory
	_roster = roster
	cost_item_id = item_id
	durability_per_item = per_item


## 모자란 내구도를 다 채우는 데 드는 비용 아이템 개수.
static func cost_for(durability: float, max_durability: float, per_item: float) -> int:
	var missing: float = max_durability - durability
	if missing <= TOLERANCE or per_item <= 0.0:
		return 0
	return ceili(missing / per_item - TOLERANCE)


## 비용 아이템 used개를 쓴 뒤의 내구도 (최대를 넘지 않는다).
static func durability_after(durability: float, max_durability: float, per_item: float, used: int) -> float:
	return minf(durability + per_item * used, max_durability)


## 이 머리뼈를 다 채우는 데 드는 개수. 머리뼈가 없으면 0.
func get_cost(skull: Skull) -> int:
	if skull == null:
		return 0
	return cost_for(skull.durability, skull.data.max_durability, durability_per_item)


## 지금 가진 비용 아이템 개수
func get_owned_count() -> int:
	return _inventory.get_count(cost_item_id)


## 지금 수리할 수 있는지만 확인한다 (아무것도 바꾸지 않는다). 할 수 있으면 OK.
func check(skull: Skull) -> Result:
	if skull == null or not _inventory.get_skulls().has(skull):
		return Result.NO_SKULL
	if _roster != null and _roster.is_summoned(skull):
		return Result.SUMMONED
	if get_cost(skull) == 0:
		return Result.FULL
	if get_owned_count() == 0:
		return Result.NO_COST_ITEM
	return Result.OK


## 비용 아이템을 써서 내구도를 채운다. 모자라면 가진 만큼만 채운다.
func repair(skull: Skull) -> Result:
	var result: Result = check(skull)
	if result != Result.OK:
		return result
	var used: int = mini(get_cost(skull), get_owned_count())
	skull.durability = durability_after(skull.durability, skull.data.max_durability, durability_per_item, used)
	# 비용 아이템을 빼면 인벤토리가 changed를 알려서, 내구도 바를 그리는 화면도 다시 그린다.
	_inventory.remove_count(cost_item_id, used)
	return Result.OK
