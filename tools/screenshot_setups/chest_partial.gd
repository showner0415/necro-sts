extends RefCounted
## 스크린샷 준비 (시험 지역): 몬스터 없는 상자(ChestSafe) 앞에서 상자를 열고, 내용물을 --reveal=<초>(기본 3.2)만큼 드러낸 상태로 만든다.
## 앞 칸 몇 개는 드러나고, 하나는 진행 바가 차는 중이고, 나머지는 "?"로 보인다. 내용물은 무작위(난수)다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/chest_partial.gd --seconds=0.5 --out=<경로>

const DEFAULT_REVEAL: float = 3.2
const STAND_OFFSET: Vector2 = Vector2(0, 16)


static func run(scene: Node) -> void:
	var reveal: float = DEFAULT_REVEAL
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reveal="):
			reveal = arg.trim_prefix("--reveal=").to_float()
	var chest: LootChest = scene.get_node("ChestSafe")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = chest.global_position + STAND_OFFSET
	chest.contents.advance(reveal)
	scene.call(&"open_chest", chest)
	print("상자 칸: %s, 드러나는 중 %d번 (%.2f)" % [
		range(chest.contents.inventory.get_slot_count()).map(func(i: int) -> String:
			var stack: ItemStack = chest.contents.inventory.get_slot(i)
			var name: String = "빈 칸" if stack == null else stack.get_display_name()
			return name if chest.contents.is_revealed(i) else "?(%s)" % name),
		chest.contents.get_revealing_index(), chest.contents.get_reveal_progress()])
