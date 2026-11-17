extends RefCounted
## 스크린샷 준비 (시험 지역): 몬스터 없는 상자(ChestSafe) 앞에서 상자를 열고, 내용물을 --reveal=<초>(기본 3.2)만큼 드러낸 상태로 만든다.
## 앞 칸 몇 개는 드러나고, 하나는 진행 바가 차는 중이고, 나머지는 "?"로 보인다. 내용물은 무작위(난수)다.
## 조준을 몸 오른쪽에 고정하고(카메라가 실제 마우스를 따라가지 않게) UI 입력을 막는다(실제 마우스가 칸 위에 있어도 정보 줄이 뜨지 않게).
## 내용물과 몬스터 움직임은 난수라서 찍을 때마다 다를 수 있다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --scene=res://regions/test_arena.tscn --setup=res://tools/screenshot_setups/chest_partial.gd --seconds=0.5 --out=<경로>

const DEFAULT_REVEAL: float = 3.2
const STAND_OFFSET: Vector2 = Vector2(0, 16)
## 몸 가운데에서 조준점까지 (오른쪽)
const AIM_DISTANCE: float = 128.0


static func run(scene: Node) -> void:
	scene.get_viewport().gui_disable_input = true
	var reveal: float = DEFAULT_REVEAL
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reveal="):
			reveal = arg.trim_prefix("--reveal=").to_float()
	var chest: LootChest = scene.get_node("ChestSafe")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = chest.global_position + STAND_OFFSET
	var view: RegionView3D = scene.call(&"get_view_3d")
	if view != null:
		view.aim_override = necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE
	chest.contents.advance(reveal)
	scene.call(&"open_chest", chest)
	print("상자 칸: %s, 드러나는 중 %d번 (%.2f)" % [
		range(chest.contents.inventory.get_slot_count()).map(func(i: int) -> String:
			var stack: ItemStack = chest.contents.inventory.get_slot(i)
			var name: String = "빈 칸" if stack == null else stack.get_display_name()
			return name if chest.contents.is_revealed(i) else "?(%s)" % name),
		chest.contents.get_revealing_index(), chest.contents.get_reveal_progress()])
