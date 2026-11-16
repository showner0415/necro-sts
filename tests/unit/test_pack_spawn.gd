extends TestCase
## PackSpawn(무리 자리) 단위 테스트: 무리원은 부모에 넣는 순간 이미 제자리여야 한다.
## (0,0)에 넣은 뒤 옮기면 2D 물리가 옮긴 만큼 넓힌 상자로 벽 모양과 쌍을 만들어, 큰 맵에서 진입이 수십 초 멈췄다
## (docs/plans/2026-11-16_region_load_plan.md). 실제 물리 쌍 수는 scenario_region_load.gd가 본다.
## 단위 테스트는 씬 트리가 시작하기 전에 돌아서 트리에 들어가는 신호가 오지 않는다. 그래서 자식을 넣을 때 오는 child_order_changed로 본다.

const RAT_PATH: String = "res://data/monsters/rat.tres"
const PACK_PATH: String = "res://data/packs/rat_gang.tres"
## 무리원을 넣을 부모의 위치 (부모가 원점이 아니어도 월드 자리가 맞는지 본다)
const ACTORS_OFFSET: Vector2 = Vector2(100, 50)
## 원점에서 먼 자리 (얕은 굴의 무리 자리처럼)
const FAR_POSITION: Vector2 = Vector2(9000, 4000)

var _root: Node2D
var _actors: Node2D
## 무리원을 넣은 순간의 월드 위치
var _added_at: Array[Vector2] = []


func before_each() -> void:
	_root = Node2D.new()
	_actors = Node2D.new()
	_actors.position = ACTORS_OFFSET
	_root.add_child(_actors)
	_added_at.clear()
	_actors.child_order_changed.connect(_on_children_changed)


func after_each() -> void:
	_root.free()


func _on_children_changed() -> void:
	if _actors.get_child_count() == 0:
		return
	var last: Node = _actors.get_child(-1)
	if last is Monster and _added_at.size() < _actors.get_child_count():
		_added_at.append((last as Monster).global_position)


func test_members_are_added_already_in_place() -> void:
	var spawn: PackSpawn = PackSpawn.new()
	spawn.name = "RatGangSpot"
	spawn.pack = load(PACK_PATH)
	_root.add_child(spawn)
	var points: Array[Vector2] = [FAR_POSITION, FAR_POSITION + Vector2(20, 0)]
	var entries: Array = []
	for i: int in points.size():
		entries.append({"index": i, "data": load(RAT_PATH), "position": points[i], "health": -1.0, "leader": false})
	spawn.spawn_saved(_actors, entries)
	assert_eq(_added_at.size(), points.size(), "무리원마다 한 번 넣음")
	for i: int in mini(_added_at.size(), points.size()):
		assert_eq(_added_at[i], points[i], "%d번 무리원: 넣는 순간 이미 제자리 (원점에 넣고 옮기지 않음)" % i)
	for i: int in points.size():
		var member: Monster = _actors.get_node_or_null("%s_%d" % [spawn.name, i]) as Monster
		assert_true(member != null and member.global_position == points[i], "%d번 무리원: 넣은 뒤에도 제자리" % i)
