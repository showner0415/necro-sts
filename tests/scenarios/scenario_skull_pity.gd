extends ScenarioTest
## 시나리오: 머리뼈 보정 (계획 7b). 시험 지역의 쥐로 본다.
## 1. 인벤토리에 머리뼈가 하나도 없으면 쥐를 잡을 때 보정 확률을 쓴다 (원래 0, 보정 1로 고정 → 머리뼈가 나온다)
## 2. 인벤토리에 머리뼈가 하나라도 있으면 원래 확률을 쓴다 (원래 0 → 머리뼈가 나오지 않는다)
## 확률 고정: 쥐 데이터를 복사해 머리뼈 확률을 0으로, 보정 값(data/skull_pity.tres)을 복사해 보정 확률을 1로 바꿔 그 쥐에만 넣는다.
## 실제 파일은 바꾸지 않는다. 0.5 → 0.8(임시값)과 세는 곳(인벤토리·내구도 0·네임드)은 단위 테스트(test_skull_pity.gd)가 본다.

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
	if rats.size() < 2:
		fail_step("쥐 찾기", "쥐 %d마리" % rats.size())
		finish(false)
		return

	# 1. 머리뼈가 없으면 보정 확률
	var first: Array[Skull] = _skulls(await _kill(rats[0], necromancer))
	var boosted_ok: bool = first.size() == 1
	if not _check("머리뼈가 없으면 보정", boosted_ok, "인벤토리 머리뼈 0개 → 시체 머리뼈 %d개 (원래 확률 0, 보정 1)" % first.size()):
		finish(false)
		return

	# 2. 머리뼈가 있으면 원래 확률
	inventory.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	var second: Array[Skull] = _skulls(await _kill(rats[1], necromancer))
	var plain_ok: bool = second.is_empty()
	_check("머리뼈가 있으면 원래 확률", plain_ok, "인벤토리 머리뼈 %d개 → 시체 머리뼈 %d개 (원래 확률 0)" % [inventory.get_skulls().size(), second.size()])
	finish(plain_ok)


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
