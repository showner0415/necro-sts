extends ScenarioTest
## 시나리오: 머리뼈 보정 (계획 7b, 구멍 고치기 7c). 시험 지역의 쥐로 본다.
## 1. 인벤토리에 머리뼈가 하나라도 있으면 원래 확률을 쓴다 (원래 0 → 머리뼈가 나오지 않는다)
## 2. 인벤토리를 비우면 보정 확률을 쓴다 (보정 1로 고정 → 머리뼈가 나온다). 시체에 머리뼈가 나왔으니 던전 상태의 표시가 켜진다
## 3. 그 뒤로는 인벤토리가 비어 있어도 이번 던전에서는 원래 확률을 쓴다 (원래 0 → 머리뼈가 나오지 않는다. 시체를 줍지 않고 계속 잡는 구멍을 막음)
## 단계마다 잡은 쥐의 시체를 찾았는지도 본다 (못 찾으면 머리뼈 0개로 잘못 통과하지 않게).
## 확률 고정: 쥐 데이터를 복사해 머리뼈 확률을 0으로, 보정 값(data/skull_pity.tres)을 복사해 보정 확률을 1로 바꿔 그 쥐에만 넣는다.
## 실제 파일은 바꾸지 않는다. 0.5 → 0.8(임시값), 세는 곳(인벤토리·내구도 0·네임드), 시체의 모든 종·네임드 머리뼈는 단위 테스트(test_skull_pity.gd)가 본다.

const PITY_PATH: String = "res://data/skull_pity.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const WAIT_FRAMES: int = 3
## 네크로맨서를 쥐들에게서 떨어뜨려 둔다
const SAFE_POSITION: Vector2 = Vector2(0, 600)


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	var necromancer: Necromancer = find_necromancer()
	necromancer.position = SAFE_POSITION
	var inventory: Inventory = root.get_node("GameState").get(&"inventory")
	inventory.clear()
	await wait_frames(WAIT_FRAMES)
	var rats: Array[Monster] = []
	for node: Node in current_scene.find_children("*", "CharacterBody2D", true, false):
		if node is Monster and (node as Monster).data.id == &"rat":
			rats.append(node as Monster)
	if rats.size() < 3:
		fail_step("쥐 찾기", "쥐 %d마리" % rats.size())
		finish(false)
		return
	var dungeon: DungeonRun = root.get_node("GameState").get(&"dungeon")

	# 1. 머리뼈가 있으면 원래 확률
	inventory.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	var first_corpse: Corpse = await _kill(rats[0], necromancer)
	var first: Array[Skull] = _skulls(first_corpse)
	var plain_ok: bool = first_corpse != null and first.is_empty() and not dungeon.skull_in_corpse
	if not _check("머리뼈가 있으면 원래 확률", plain_ok, "인벤토리 머리뼈 %d개 → 시체 %s, 시체 머리뼈 %d개 (원래 확률 0), 시체에 나온 적 %s" % [
			inventory.get_skulls().size(), first_corpse != null, first.size(), dungeon.skull_in_corpse]):
		finish(false)
		return

	# 2. 머리뼈가 없으면 보정 확률, 시체에 나왔으니 표시가 켜진다
	inventory.clear()
	var second_corpse: Corpse = await _kill(rats[1], necromancer)
	var second: Array[Skull] = _skulls(second_corpse)
	var boosted_ok: bool = second.size() == 1 and dungeon.skull_in_corpse
	if not _check("머리뼈가 없으면 보정", boosted_ok, "인벤토리 머리뼈 0개 → 시체 %s, 시체 머리뼈 %d개 (원래 확률 0, 보정 1), 시체에 나온 적 %s" % [
			second_corpse != null, second.size(), dungeon.skull_in_corpse]):
		finish(false)
		return

	# 3. 시체를 줍지 않아 인벤토리가 비어 있어도, 이번 던전에서는 보정이 끝났다
	var third_corpse: Corpse = await _kill(rats[2], necromancer)
	var third: Array[Skull] = _skulls(third_corpse)
	var ended_ok: bool = third_corpse != null and third.is_empty()
	_check("시체에 나온 뒤에는 보정 없음", ended_ok, "인벤토리 머리뼈 %d개, 시체에 나온 적 %s → 시체 %s, 시체 머리뼈 %d개 (원래 확률 0)" % [
			inventory.get_skulls().size(), dungeon.skull_in_corpse, third_corpse != null, third.size()])
	finish(ended_ok)


## 쥐의 데이터와 보정 값을 고정한 복사본으로 바꾸고 잡는다. 그 자리에 남은 시체를 돌려준다 (없으면 null).
func _kill(rat: Monster, source: Node2D) -> Corpse:
	var data: MonsterData = rat.data.duplicate()
	var drops: Array[DropEntry] = []
	for entry: DropEntry in rat.data.drops:
		var entry_copy: DropEntry = entry.duplicate()
		if entry_copy.item is SkullData:
			entry_copy.chance = 0.0
		drops.append(entry_copy)
	data.drops = drops
	rat.data = data
	var pity: SkullPity = (load(PITY_PATH) as SkullPity).duplicate()
	pity.boosted_chance = 1.0
	rat.skull_pity = pity
	var at: Vector2 = rat.global_position
	rat.take_damage(rat.health + 1.0, source)
	await wait_frames(WAIT_FRAMES)
	for node: Node in current_scene.find_children("*", "Area2D", true, false):
		var corpse: Corpse = node as Corpse
		if corpse != null and corpse.global_position.is_equal_approx(at):
			return corpse
	return null


func _skulls(corpse: Corpse) -> Array[Skull]:
	var skulls: Array[Skull] = []
	if corpse == null:
		return skulls
	for stack: ItemStack in corpse.loot.get_stacks():
		if stack.is_skull():
			skulls.append(stack.skull)
	return skulls


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok
