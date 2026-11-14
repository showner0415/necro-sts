class_name RegionSnapshot
extends RefCounted
## 던전 지역을 떠날 때의 상태를 사전으로 담고, 돌아올 때 되살린다 (계획 5단계, DungeonRun이 지역 id로 든다).
## 담는 것 (사용자 결정 2026-11-14): 씬에 놓인 몬스터의 위치·체력과 죽은 몬스터, 시체(루팅 상태 포함), 바닥 물건, 상자(연 상태와 남은 물건).
## - 몬스터는 지역 씬에서의 경로로 가린다. 씬에 놓인 몬스터(owner가 지역)만 여기서 담고, 무리 자리(PackSpawn)가 만든 무리원은 자리마다 "packs"에 담는다 (되살리기는 Region이 자리에 맡긴다)
## - 쫓던 무리는 떠나는 순간 대상을 놓친 것으로 본다: 대상·경보는 담지 않아서 돌아오면 그 자리에서 배회한다
## - 시체·바닥 물건은 지역 씬의 것을 모두 지우고 담은 것으로 다시 놓는다. 상자는 경로로 가려 담은 내용물로 바꾼다
## 시체와 루팅 상태(CorpseLoot), 바닥 물건(ItemStack), 상자 내용물(ChestContents)은 객체를 그대로 든다 (파일로 저장하지 않는다).

const CORPSE_SCENE: String = "res://monsters/corpse.tscn"
const PICKUP_SCENE: String = "res://items/pickup.tscn"


static func capture(region: Node) -> Dictionary:
	var monsters: Dictionary = {}
	for node: Node in nodes_of(region, Monster):
		var monster: Monster = node as Monster
		if monster.owner != region or monster.is_queued_for_deletion() or monster.health <= 0.0:
			continue
		monsters[str(region.get_path_to(monster))] = {"position": monster.global_position, "health": monster.health}
	var corpses: Array[Dictionary] = []
	for node: Node in nodes_of(region, Corpse):
		var corpse: Corpse = node as Corpse
		corpses.append({"data": corpse.data, "loot": corpse.loot, "position": corpse.global_position})
	var pickups: Array[Dictionary] = []
	for node: Node in nodes_of(region, Pickup):
		if node.is_queued_for_deletion():
			continue
		var pickup: Pickup = node as Pickup
		pickups.append({"stack": pickup.stack, "position": pickup.global_position})
	var chests: Dictionary = {}
	for node: Node in nodes_of(region, LootChest):
		var chest: LootChest = node as LootChest
		chests[str(region.get_path_to(chest))] = chest.contents
	var packs: Dictionary = {}
	for node: Node in nodes_of(region, PackSpawn):
		packs[str(region.get_path_to(node))] = (node as PackSpawn).capture()
	return {"monsters": monsters, "corpses": corpses, "pickups": pickups, "chests": chests, "packs": packs}


## 지역 씬이 준비된 직후(_ready)에 부른다. actors는 시체·바닥 물건을 넣을 부모(지역의 Actors)다.
static func restore(region: Node, actors: Node, snapshot: Dictionary) -> void:
	var monsters: Dictionary = snapshot.get("monsters", {})
	for node: Node in nodes_of(region, Monster):
		var monster: Monster = node as Monster
		if monster.owner != region:
			continue
		var key: String = str(region.get_path_to(monster))
		if not monsters.has(key):
			# 떠나기 전에 죽은 몬스터는 다시 생기지 않는다.
			monster.get_parent().remove_child(monster)
			monster.queue_free()
			continue
		monster.global_position = monsters[key]["position"]
		monster.health = monsters[key]["health"]
	for node: Node in nodes_of(region, Corpse) + nodes_of(region, Pickup):
		node.get_parent().remove_child(node)
		node.queue_free()
	for entry: Dictionary in snapshot.get("corpses", []):
		var corpse: Corpse = (load(CORPSE_SCENE) as PackedScene).instantiate()
		corpse.setup(entry["data"], entry["loot"])
		actors.add_child(corpse)
		corpse.global_position = entry["position"]
	for entry: Dictionary in snapshot.get("pickups", []):
		var pickup: Pickup = (load(PICKUP_SCENE) as PackedScene).instantiate()
		pickup.stack = entry["stack"]
		actors.add_child(pickup)
		pickup.global_position = entry["position"]
	var chests: Dictionary = snapshot.get("chests", {})
	for node: Node in nodes_of(region, LootChest):
		var chest: LootChest = node as LootChest
		var key: String = str(region.get_path_to(chest))
		if chests.has(key):
			chest.contents = chests[key]
			chest.queue_redraw()


## region 아래의 노드 중 type(스크립트 클래스)인 것들. find_children의 type은 엔진 클래스만 가려서 쓰지 않는다.
static func nodes_of(region: Node, type: Script) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in region.find_children("*", "", true, false):
		if is_instance_of(node, type):
			found.append(node)
	return found
