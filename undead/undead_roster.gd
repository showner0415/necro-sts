class_name UndeadRoster
extends RefCounted
## 소환 규칙과 지금 소환 중인 머리뼈 목록. 노드에 의존하지 않으므로 씬 없이 만들어 쓰고 확인할 수 있다.
## 실제 언데드 노드를 만들고 없애는 일은 바깥(Summoner)이 summoned / unsummoned 시그널을 받아서 한다.
##
## 규칙 (docs/game-design.md "소환과 언데드"):
## - 머리뼈 하나로 한 마리. 여러 머리뼈로 여러 마리를 동시에 소환할 수 있다
## - 처음 소환할 때 뼈(몬스터 데이터의 처음 소환 비용)를 쓰고 체력이 가득 찬다. 소환마다 마나를 쓴다
## - 체력 0이거나 내구도 0이면 소환할 수 없다
## - 피해를 받으면 체력이 줄고 내구도가 durability_loss_per_hit만큼 준다
## - 체력이 0이 되면 죽은 판정: 내구도가 몬스터 데이터의 값만큼 준다 (죽는 일격의 피해 내구도는 따로 깎지 않는다)
## - 소환 중에 내구도가 0이 되면 일반 해제
## - 인벤토리에서 사라지면(버리기) 죽은 판정, 핫바에서만 빠지면 일반 해제
## - 살아 있는 수만큼 마나가 초당 빠지고, 마나가 0이 되면 전부 일반 해제
## - 해제된 머리뼈의 체력은 뼈로 회복한다 (UndeadRules)
## - 뼈 제거: 해제된 머리뼈의 지금 체력에 해당하는 뼈를 인벤토리로 돌려받고, 머리뼈는 처음 소환 전 상태가 된다 (내구도는 그대로)

## 소환·회복을 시도한 결과
enum Result {
	OK,
	## 머리뼈가 없거나, 인벤토리·핫바에 없음
	NO_SKULL,
	## 이미 소환 중 (회복할 때)
	SUMMONED,
	## 원본 몬스터 데이터를 찾지 못함
	UNKNOWN_MONSTER,
	## 내구도 0
	BROKEN,
	## 체력 0 (회복이 필요함)
	NO_HEALTH,
	## 처음 소환할 뼈가 모자람
	NOT_ENOUGH_BONES,
	NOT_ENOUGH_MANA,
	## 회복: 아직 깨우지 않은 머리뼈 (처음 소환하면 체력이 가득 찬다)
	NOT_AWAKENED,
	## 회복: 이미 가득 참
	FULL_HEALTH,
	## 회복: 뼈가 하나도 없음 / 뼈 제거: 머리뼈에 돌려받을 뼈가 없음
	NO_BONES,
	## 뼈 제거: 돌려받을 뼈를 넣을 자리가 인벤토리에 없음
	INVENTORY_FULL,
}

signal summoned(skull: Skull)
## died가 true면 죽은 판정, false면 일반 해제
signal unsummoned(skull: Skull, died: bool)
## 소환 목록이나 머리뼈의 체력·내구도가 바뀌면 알린다 (화면 갱신용)
signal changed

## 언데드가 피해를 한 번 받을 때 줄어드는 머리뼈 내구도
var durability_loss_per_hit: float

var _inventory: Inventory
var _hotbar: Hotbar
var _mana: ManaPool
var _bone_id: StringName
## func(id: StringName) -> MonsterData
var _find_monster: Callable
var _summoned: Array[Skull] = []


func _init(inventory: Inventory, hotbar: Hotbar, mana: ManaPool, bone_id: StringName, find_monster: Callable, hit_durability_loss: float) -> void:
	_inventory = inventory
	_hotbar = hotbar
	_mana = mana
	_bone_id = bone_id
	_find_monster = find_monster
	durability_loss_per_hit = hit_durability_loss
	_inventory.changed.connect(_on_inventory_changed)
	_hotbar.changed.connect(_on_hotbar_changed)
	_mana.changed.connect(_on_mana_changed)


func is_summoned(skull: Skull) -> bool:
	return _summoned.has(skull)


func get_summoned() -> Array[Skull]:
	return _summoned.duplicate()


func get_count() -> int:
	return _summoned.size()


## 그 머리뼈의 원본 몬스터 데이터. 못 찾으면 null.
func get_monster(skull: Skull) -> MonsterData:
	if skull == null:
		return null
	return _find_monster.call(skull.data.source_monster_id)


## 소환 중이면 해제하고, 아니면 소환한다. 해제했으면 OK.
func toggle(skull: Skull) -> Result:
	if is_summoned(skull):
		unsummon(skull)
		return Result.OK
	return summon(skull)


func summon(skull: Skull) -> Result:
	if skull == null or not _inventory.get_skulls().has(skull) or _hotbar.find_slot(skull) == -1:
		return Result.NO_SKULL
	if is_summoned(skull):
		return Result.SUMMONED
	var monster: MonsterData = get_monster(skull)
	if monster == null:
		return Result.UNKNOWN_MONSTER
	if skull.is_broken():
		return Result.BROKEN
	if skull.awakened and skull.health <= 0.0:
		return Result.NO_HEALTH
	if not skull.awakened and _inventory.get_count(_bone_id) < monster.summon_bone_cost:
		return Result.NOT_ENOUGH_BONES
	if not _mana.can_spend(monster.summon_mana_cost):
		return Result.NOT_ENOUGH_MANA

	if not skull.awakened:
		_inventory.remove_count(_bone_id, monster.summon_bone_cost)
		skull.awakened = true
		skull.health = monster.undead_max_health
	# 목록에 먼저 넣는다: 비용을 내고 마나가 0이 되면 이 언데드도 같이 해제되어야 한다.
	_summoned.append(skull)
	summoned.emit(skull)
	_mana.try_spend(monster.summon_mana_cost)
	changed.emit()
	return Result.OK


## 일반 해제. 체력과 내구도는 그대로 남는다.
func unsummon(skull: Skull) -> void:
	if not is_summoned(skull):
		return
	_summoned.erase(skull)
	unsummoned.emit(skull, false)
	changed.emit()


## 죽은 판정. 사라지고 체력은 0, 내구도는 몬스터 데이터의 값만큼 준다.
func kill(skull: Skull) -> void:
	if not is_summoned(skull):
		return
	_summoned.erase(skull)
	skull.health = 0.0
	var monster: MonsterData = get_monster(skull)
	if monster != null:
		skull.lose_durability(monster.undead_death_durability_loss)
	unsummoned.emit(skull, true)
	changed.emit()


## 소환 중인 언데드가 피해를 받음.
func damage(skull: Skull, amount: float) -> void:
	if not is_summoned(skull) or amount <= 0.0:
		return
	skull.health = maxf(skull.health - amount, 0.0)
	if skull.health <= 0.0:
		kill(skull)
		return
	skull.lose_durability(durability_loss_per_hit)
	if skull.is_broken():
		unsummon(skull)
		return
	changed.emit()


func unsummon_all() -> void:
	for skull: Skull in _summoned.duplicate():
		unsummon(skull)


## 지금 가득 채우려면 필요한 뼈 개수. 깨우지 않은 머리뼈는 처음 소환 비용.
func get_heal_bone_cost(skull: Skull) -> int:
	var monster: MonsterData = get_monster(skull)
	if monster == null:
		return 0
	if not skull.awakened:
		return monster.summon_bone_cost
	return UndeadRules.heal_bone_cost(skull.health, monster.undead_max_health, monster.summon_bone_cost)


## 지금 회복할 수 있는지만 확인한다 (아무것도 바꾸지 않는다). 할 수 있으면 OK.
## 핫바 + R과 인벤토리 메뉴의 "회복하기"가 같이 쓴다.
func check_heal(skull: Skull) -> Result:
	if skull == null or not _inventory.get_skulls().has(skull):
		return Result.NO_SKULL
	if is_summoned(skull):
		return Result.SUMMONED
	var monster: MonsterData = get_monster(skull)
	if monster == null:
		return Result.UNKNOWN_MONSTER
	if not skull.awakened:
		return Result.NOT_AWAKENED
	if UndeadRules.heal_bone_cost(skull.health, monster.undead_max_health, monster.summon_bone_cost) == 0:
		return Result.FULL_HEALTH
	if _inventory.get_count(_bone_id) == 0:
		return Result.NO_BONES
	return Result.OK


## 뼈를 써서 해제된 머리뼈의 체력을 회복한다. 뼈가 모자라면 가진 만큼 일부 회복한다.
func heal(skull: Skull) -> Result:
	var check: Result = check_heal(skull)
	if check != Result.OK:
		return check
	var monster: MonsterData = get_monster(skull)
	var needed: int = UndeadRules.heal_bone_cost(skull.health, monster.undead_max_health, monster.summon_bone_cost)
	var used: int = mini(needed, _inventory.get_count(_bone_id))
	skull.health = UndeadRules.health_after_heal(skull.health, monster.undead_max_health, monster.summon_bone_cost, used)
	_inventory.remove_count(_bone_id, used)
	changed.emit()
	return Result.OK


## 뼈 제거로 돌려받을 뼈 개수 (지금 체력만큼). 깨우지 않은 머리뼈는 0.
func get_stored_bones(skull: Skull) -> int:
	var monster: MonsterData = get_monster(skull)
	if skull == null or monster == null or not skull.awakened:
		return 0
	return UndeadRules.stored_bones(skull.health, monster.undead_max_health, monster.summon_bone_cost)


## 지금 뼈를 제거할 수 있는지만 확인한다 (아무것도 바꾸지 않는다). bone_item은 돌려받을 뼈 아이템.
func check_remove_bones(skull: Skull, bone_item: ItemData) -> Result:
	if skull == null or not _inventory.get_skulls().has(skull):
		return Result.NO_SKULL
	if is_summoned(skull):
		return Result.SUMMONED
	if get_monster(skull) == null:
		return Result.UNKNOWN_MONSTER
	if not skull.awakened:
		return Result.NOT_AWAKENED
	var bones: int = get_stored_bones(skull)
	if bones == 0:
		return Result.NO_BONES
	if not _inventory.can_add(ItemStack.of_item(bone_item, bones)):
		return Result.INVENTORY_FULL
	return Result.OK


## 해제된 머리뼈에서 뼈를 빼서 인벤토리로 돌려준다. 머리뼈는 처음 소환 전 상태(깨우지 않음, 체력 0)가 된다.
## 다시 쓰려면 처음 소환 비용을 다시 낸다. 내구도는 그대로다.
func remove_bones(skull: Skull, bone_item: ItemData) -> Result:
	var check: Result = check_remove_bones(skull, bone_item)
	if check != Result.OK:
		return check
	var bones: int = get_stored_bones(skull)
	skull.awakened = false
	skull.health = 0.0
	_inventory.try_add(ItemStack.of_item(bone_item, bones))
	changed.emit()
	return Result.OK


## 소환 중인 언데드 전체의 유지비 (초당 마나). 몬스터 데이터의 값을 마리마다 더한다.
func get_upkeep_per_second() -> float:
	var total: float = 0.0
	for skull: Skull in _summoned:
		var monster: MonsterData = get_monster(skull)
		if monster != null:
			total += monster.undead_upkeep_mana_per_second
	return total


## 물리 프레임마다 부른다: 소환 중인 언데드의 유지비만큼 마나를 뺀다.
func process(delta: float) -> void:
	if _summoned.is_empty():
		return
	_mana.drain(get_upkeep_per_second() * delta)


func _on_mana_changed(_current: float, _maximum: float) -> void:
	if _mana.is_empty():
		unsummon_all()


## 버리기 등으로 인벤토리에서 사라진 머리뼈는 죽은 판정.
func _on_inventory_changed() -> void:
	var owned: Array[Skull] = _inventory.get_skulls()
	for skull: Skull in _summoned.duplicate():
		if not owned.has(skull):
			kill(skull)


## 핫바에서만 빠진 머리뼈는 일반 해제.
## 인벤토리에서 버리면 핫바도 같이 비지만, 그때는 인벤토리 쪽에서 죽은 판정을 하므로 여기서는 건너뛴다.
func _on_hotbar_changed() -> void:
	var owned: Array[Skull] = _inventory.get_skulls()
	for skull: Skull in _summoned.duplicate():
		if owned.has(skull) and _hotbar.find_slot(skull) == -1:
			unsummon(skull)
