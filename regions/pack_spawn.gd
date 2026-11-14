class_name PackSpawn
extends Node2D
## 무리 자리 (계획 5b). 지역이 시작할 때 이 자리에 무리(몬스터 + MonsterPack)를 만든다. 맵 PNG의 무리 색 픽셀 하나가 이 노드 하나다.
## - 처음 들어온 지역이면 pack(PackData)과 던전 시드 난수로 수를 정하고, 자리에서 spread_radius 안에 흩어 놓는다 (PackPlacer)
## - 던전 안에서 다시 들어온 지역이면 떠날 때 담은 무리원(capture)만 그 자리·체력으로 되살린다 (죽은 무리원은 다시 생기지 않는다)
## 무리원 이름은 "<자리 이름>_<번호>", 무리 노드 이름은 "<자리 이름>Pack"이다 (번호는 처음 만들 때의 순서라 되살려도 같다).
## - 대장(계획 6a): 처음 만들 때 PackLeader로 고르고 체력을 대장 배율만큼 늘린다. 되살릴 때는 담은 대장 여부·체력을 그대로 쓴다 (죽은 대장은 다시 생기지 않아 강화도 없다)

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
## 대장 값을 따로 넣지 않으면 이 값을 쓴다 (확률 15%, 공격력 1.2배, 체력 1.5배, 모두 임시값)
const DEFAULT_LEADER_SETTINGS: String = "res://data/packs/leader_settings.tres"

## 이 자리의 무리 종류
@export var pack: PackData
## 무리원을 놓을 범위 (자리에서 픽셀, 사용자 결정 2026-11-14, 임시값)
@export var spread_radius: float = 48.0
## 무리원끼리 이만큼(픽셀) 떨어뜨려 놓는다 (사용자 결정 2026-11-14, 임시값)
@export var min_spacing: float = 16.0
## 놓을 곳을 다시 고르는 횟수 (사용자 결정 2026-11-14, 임시값). 끝내 못 고르면 자리 한가운데에 둔다
@export var place_tries: int = 30
## 무리 대장 값 (비우면 DEFAULT_LEADER_SETTINGS)
@export var leader_settings: PackLeaderSettings

## 이 자리에서 만든 무리원 (번호 → 몬스터)
var _members: Dictionary = {}


## 처음 만든다. actors는 몬스터를 넣을 부모, is_free(점)는 그 점이 바닥이면 true.
## 대장은 확률로(forced_leader면 반드시) 무리원 중 하나가 되고, 체력이 대장 배율만큼 크다 (계획 6a).
func spawn(actors: Node, rng: RandomNumberGenerator, is_free: Callable, forced_leader: bool = false) -> void:
	if pack == null:
		return
	var datas: Array[MonsterData] = pack.roll(rng)
	var points: PackedVector2Array = PackPlacer.place(global_position, datas.size(), spread_radius, min_spacing, rng, is_free, place_tries)
	var entries: Array[Dictionary] = []
	for i: int in datas.size():
		entries.append({"index": i, "data": datas[i], "position": points[i], "health": -1.0, "leader": false})
	var settings: PackLeaderSettings = _leader_settings()
	var leader: int = PackLeader.pick(entries.size(), settings.chance, forced_leader, rng)
	if leader >= 0:
		entries[leader]["leader"] = true
		entries[leader]["health"] = datas[leader].max_health * settings.leader_health_ratio
	_build(actors, entries)


## 떠날 때 담은 무리원(capture의 결과)으로 되살린다.
func spawn_saved(actors: Node, entries: Array) -> void:
	_build(actors, entries)


## 살아 있는 무리원: [{"index", "data", "position", "health", "leader"}]
func capture() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index: int in _members:
		# 죽은 무리원은 이미 사라졌을 수 있다. 사라진 객체를 타입 있는 변수에 넣으면 오류이므로 먼저 확인한다.
		if not is_instance_valid(_members[index]):
			continue
		var monster: Monster = _members[index]
		if monster.is_queued_for_deletion() or monster.health <= 0.0:
			continue
		entries.append({"index": index, "data": monster.data, "position": monster.global_position, "health": monster.health, "leader": monster.is_leader})
	return entries


## 테스트·디버그용: 지금 살아 있는 무리원
func get_members() -> Array[Monster]:
	var alive: Array[Monster] = []
	for index: int in _members:
		if is_instance_valid(_members[index]):
			alive.append(_members[index])
	return alive


## entries의 health가 0보다 크면 그 체력으로 둔다 (아니면 데이터의 최대 체력).
func _build(actors: Node, entries: Array) -> void:
	var monsters: Array[Monster] = []
	for entry: Dictionary in entries:
		var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		monster.data = entry["data"]
		monster.name = "%s_%d" % [name, entry["index"]]
		actors.add_child(monster)
		monster.global_position = entry["position"]
		if entry["health"] > 0.0:
			monster.health = entry["health"]
		monster.is_leader = entry.get("leader", false)
		if monster.is_leader:
			monster.leader_settings = _leader_settings()
		_members[entry["index"]] = monster
		monsters.append(monster)
	if monsters.is_empty():
		return
	var monster_pack: MonsterPack = MonsterPack.new()
	monster_pack.name = "%sPack" % name
	monster_pack.set_members(monsters)
	for monster: Monster in monsters:
		if monster.is_leader:
			monster_pack.set_leader(monster, _leader_settings().member_damage_ratio)
	add_sibling(monster_pack)


func _leader_settings() -> PackLeaderSettings:
	return leader_settings if leader_settings != null else load(DEFAULT_LEADER_SETTINGS)
