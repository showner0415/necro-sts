extends RefCounted
## 시험 지역을 밸런스 측정(tests/balance/run_balance.gd)과 같은 싸움터로 만든다: 다른 몬스터와 탈출 지점을 치우고,
## 네크로맨서는 가운데, 대상은 측정과 같은 자리에 둔다. 언데드를 쓰면 쥐 머리뼈를 핫바에 넣고 뼈를 준다 (소환은 1 → G, 2 → G).
## 사람이 직접 해 볼 때는 tools/play_case.gd로, 화면 확인은 screenshot.gd --setup으로 쓴다.
## 인자: --target=bat_pack (TARGETS의 id: rat, boar, bat_pack, goblin_pair), --undead=2 (쥐 언데드 수, 0~2)

const BALANCE: GDScript = preload("res://tests/balance/run_balance.gd")


static func run(scene: Node) -> void:
	var target_id: StringName = &"bat_pack"
	var undead_count: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--target="):
			target_id = StringName(arg.trim_prefix("--target="))
		elif arg.begins_with("--undead="):
			undead_count = arg.trim_prefix("--undead=").to_int()
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in scene.find_children("*", "EscapePoint", true, false):
		node.free()
	necromancer.global_position = Vector2.ZERO

	var target: Dictionary = BALANCE.TARGETS[target_id]
	var data: MonsterData = load(target["data"])
	var spawned: Array[Monster] = []
	for offset: Vector2 in target["offsets"]:
		var monster: Monster = (load(BALANCE.MONSTER_SCENE) as PackedScene).instantiate()
		monster.data = data
		monster.position = BALANCE.SPAWN_OFFSET + offset
		necromancer.get_parent().add_child(monster)
		spawned.append(monster)
	if target.get("pack", false):
		var pack: MonsterPack = MonsterPack.new()
		pack.set_members(spawned)
		scene.add_child(pack)

	if undead_count > 0:
		var hotbar: Hotbar = tree.root.get_node("GameState").hotbar
		for i: int in undead_count:
			var skull: Skull = Skull.create(load(BALANCE.RAT_SKULL_PATH))
			necromancer.inventory.try_add(ItemStack.of_skull(skull))
			hotbar.assign(i, skull)
		necromancer.inventory.try_add(ItemStack.of_item(load(BALANCE.BONE_PATH), BALANCE.UNDEAD_BONES))
	print("시험 상황: %s, 쥐 머리뼈 %d개" % [target["name"], undead_count])
