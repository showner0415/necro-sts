class_name DungeonRun
extends RefCounted
## 던전에 한 번 들어가 거점으로 돌아올 때까지의 상태 (계획 5단계). 노드에 의존하지 않는다. GameState가 하나 든다.
## - 거점에서 던전 지역에 처음 들어갈 때 start(시드)로 시작하고, 거점에 들어가면 clear()로 비운다 (몬스터 초기화)
## - 지역을 떠날 때 그 지역의 상태(스냅샷: RegionSnapshot.capture가 만든 사전)를 지역 id로 저장하고, 돌아오면 꺼내 되살린다
## - 무리 규칙의 무작위(대장, 소수 뼈 등)는 이 시드 난수를 쓴다 (테스트·측정 재현용, 계획 9)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _active: bool = false
## 대장을 확정으로 낼 무리 종류 id (퀘스트 대상 무리. 퀘스트와 잇는 것은 나중, 계획 6a)
var forced_leader_packs: Array[StringName] = []
## 지역 id → 스냅샷
var _snapshots: Dictionary = {}


## 던전에 들어간다. 저장해 둔 지역 상태를 비우고 시드를 정한다.
func start(seed_value: int) -> void:
	_active = true
	rng.seed = seed_value
	_snapshots.clear()


## 던전에 들어가 있는지 (거점에서 나온 뒤 아직 거점에 돌아가지 않음)
func is_active() -> bool:
	return _active


## 거점에 들어가면 부른다: 지역 상태를 모두 버린다. 다음 입장 때 몬스터가 새로 생긴다.
func clear() -> void:
	_active = false
	_snapshots.clear()


func save(region_id: StringName, snapshot: Dictionary) -> void:
	_snapshots[region_id] = snapshot


func has_snapshot(region_id: StringName) -> bool:
	return _snapshots.has(region_id)


## 저장한 지역 상태 (없으면 빈 사전)
func get_snapshot(region_id: StringName) -> Dictionary:
	return _snapshots.get(region_id, {})


## 이 무리 종류에는 반드시 대장을 내는지
func forces_leader(pack_id: StringName) -> bool:
	return forced_leader_packs.has(pack_id)
