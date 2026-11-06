class_name ChestContents
extends RefCounted
## 상자 하나의 내용물과 "무엇인지 드러나기" 진행. 지역 상자(LootChest)가 하나 갖는다.
## - 처음에는 모든 칸이 잠겨 있다 (무엇인지 모름, 빈 칸도). 잠긴 칸은 꺼낼 수도 넣을 수도 없다 (Inventory.set_locked)
## - advance(delta)를 부르는 동안만 진행한다 (상자 창이 열려 있을 때만 지역 씬이 부른다)
## - 앞 칸부터 차례로, 한 번에 하나씩 드러난다. 한 칸에 걸리는 시간은 그 칸 아이템의 희귀도(RarityData.reveal_time)다.
##   빈 칸은 상자 데이터의 empty_rarity 시간이 걸린다
## - 드러난 칸은 계속 드러난 채로 남는다 (창을 닫았다 다시 열어도)
## 노드에 의존하지 않으므로 씬 없이 확인할 수 있다.

## 상자 칸들 (창고처럼 끌어서 옮기고, 메뉴로 보낸다)
var inventory: Inventory
## 칸마다 드러나는 데 걸리는 시간 (초)
var reveal_times: Array[float] = []
## 지금 드러나는 중인 칸 (모두 드러났으면 칸 수와 같다)
var _next: int = 0
## 지금 칸이 드러나기까지 흐른 시간
var _elapsed: float = 0.0


## stacks: 칸마다 든 물건 (null이면 빈 칸), times: 칸마다 드러나는 시간. 모든 칸을 잠근 채로 만든다.
func _init(stacks: Array[ItemStack], times: Array[float], display_name: String = "상자") -> void:
	inventory = Inventory.new(stacks.size())
	inventory.display_name = display_name
	inventory.fill(stacks)
	reveal_times = times
	for i: int in stacks.size():
		inventory.set_locked(i, true)


## 상자 데이터로 칸마다 내용물을 굴려 만든다 (지역에 들어올 때마다 새로).
static func roll(data: ChestData) -> ChestContents:
	var stacks: Array[ItemStack] = []
	var times: Array[float] = []
	for i: int in data.slot_count:
		var entry: ChestLootEntry = _pick(data.entries)
		var stack: ItemStack = _make_stack(entry)
		stacks.append(stack)
		var rarity: RarityData = stack.item.rarity if stack != null else data.empty_rarity
		times.append(get_reveal_time(rarity))
	return ChestContents.new(stacks, times, data.display_name)


## 희귀도의 드러나는 시간. 희귀도가 없으면 0 (바로 드러남).
static func get_reveal_time(rarity: RarityData) -> float:
	return rarity.reveal_time if rarity != null else 0.0


## 상자 창이 열려 있는 동안 물리 프레임마다 부른다. 시간이 다 된 칸을 차례로 드러낸다.
func advance(delta: float) -> void:
	var remaining: float = delta
	while _next < reveal_times.size():
		var need: float = reveal_times[_next] - _elapsed
		# 소수 오차로 다 찬 칸이 한 프레임 늦게 드러나지 않게 아주 작은 오차는 다 찬 것으로 본다.
		if remaining < need - 0.000001:
			_elapsed += remaining
			return
		remaining -= need
		inventory.set_locked(_next, false)
		_next += 1
		_elapsed = 0.0


func is_revealed(index: int) -> bool:
	return not inventory.is_locked(index)


func is_all_revealed() -> bool:
	return _next >= reveal_times.size()


## 지금 드러나는 중인 칸 번호. 모두 드러났으면 -1.
func get_revealing_index() -> int:
	return _next if not is_all_revealed() else -1


## 지금 드러나는 중인 칸의 진행 비율 (0~1). 모두 드러났으면 1.
func get_reveal_progress() -> float:
	if is_all_revealed():
		return 1.0
	var need: float = reveal_times[_next]
	return clampf(_elapsed / need, 0.0, 1.0) if need > 0.0 else 1.0


static func _pick(entries: Array[ChestLootEntry]) -> ChestLootEntry:
	var total: float = 0.0
	for entry: ChestLootEntry in entries:
		total += entry.weight
	var roll_value: float = randf() * total
	for entry: ChestLootEntry in entries:
		roll_value -= entry.weight
		if roll_value < 0.0:
			return entry
	return entries.back() if not entries.is_empty() else null


static func _make_stack(entry: ChestLootEntry) -> ItemStack:
	if entry == null or entry.item == null:
		return null
	if entry.item is SkullData:
		return ItemStack.of_skull(Skull.create(entry.item as SkullData))
	return ItemStack.of_item(entry.item, randi_range(entry.min_count, entry.max_count))
