extends RefCounted
## 스크린샷 준비: 네크로맨서 옆에 쥐의 시체(채집 중, 화면 아래에 채집 게이지)와, 조금 떨어진 곳에 빈 시체를 둔다.
## 찍을 때 게이지가 다 차지 않도록 채집 기본 시간을 길게 바꾼 복사본 데이터를 쓴다 (실제 데이터 파일은 그대로).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/harvest.gd --out=<경로>

const RAT_PATH: String = "res://data/monsters/rat.tres"
const CORPSE_SCENE_PATH: String = "res://monsters/corpse.tscn"
## 쥐가 오지 않는 남쪽
const SAFE_POSITION: Vector2 = Vector2(0, 600)
const CORPSE_OFFSET: Vector2 = Vector2(8, 0)
const EMPTY_CORPSE_OFFSET: Vector2 = Vector2(-40, 0)
## 2초에 찍을 때 게이지가 반쯤 차 있도록 하는 채집 기본 시간 (초)
const SLOW_HARVEST_TIME: float = 4.0


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.position = SAFE_POSITION
	var rat: MonsterData = load(RAT_PATH)

	var empty_corpse: Corpse = _spawn_corpse(necromancer, rat, CORPSE_OFFSET + EMPTY_CORPSE_OFFSET, [])
	empty_corpse.queue_redraw()

	var drops: Array[DropEntry] = rat.drops
	var corpse: Corpse = _spawn_corpse(necromancer, rat, CORPSE_OFFSET, drops)
	corpse.loot.base_time = SLOW_HARVEST_TIME
	necromancer.call(&"_start_harvest", corpse)


static func _spawn_corpse(necromancer: Necromancer, rat: MonsterData, offset: Vector2, drops: Array[DropEntry]) -> Corpse:
	var corpse: Corpse = (load(CORPSE_SCENE_PATH) as PackedScene).instantiate()
	corpse.setup(rat, CorpseLoot.from_drops(drops, rat.harvest_base_time))
	necromancer.get_parent().add_child(corpse)
	corpse.global_position = necromancer.global_position + offset
	return corpse
