extends RefCounted
## 스크린샷 준비: 적 멧돼지와 언데드 멧돼지가 동시에 돌진 예고 중인 장면.
## 적 멧돼지의 방향 선(빨강)은 네크로맨서를, 언데드 멧돼지의 방향 선(청록)은 그 옆의 쥐를 가리킨다.
## 예고는 0.7초라서 짧게 기다렸다 찍는다:
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=0.4 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/boar_windup.gd --out=<경로>

const BOAR_SKULL_PATH: String = "res://data/skulls/boar_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 20
## 적 멧돼지에게서 이만큼 떨어져 선다 (돌진 거리 90 안)
const NECROMANCER_OFFSET: Vector2 = Vector2(-85, 0)
## 언데드 멧돼지는 네크로맨서 아래, 쥐는 그 오른쪽
const UNDEAD_OFFSET: Vector2 = Vector2(-20, 60)
const RAT_OFFSET: Vector2 = Vector2(60, 0)


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	var boar: Monster = scene.get_node("Actors/Boar1")
	necromancer.global_position = boar.global_position + NECROMANCER_OFFSET

	var skull: Skull = Skull.create(load(BOAR_SKULL_PATH))
	necromancer.inventory.try_add(ItemStack.of_skull(skull))
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = tree.root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	necromancer.summoner.toggle_selected()
	var undead: Undead = tree.get_first_node_in_group(&"undead")
	undead.global_position = necromancer.global_position + UNDEAD_OFFSET
	var rat: Monster = scene.get_node("Actors/Rat4")
	rat.global_position = undead.global_position + RAT_OFFSET
