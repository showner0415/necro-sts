class_name MonsterPack
extends Node
## 몬스터 무리. members의 몬스터들이 함께 싸우고(한 멤버라도 어그로가 끌리면 무리 전체가 그 대상을 노린다, PackAggro),
## 함께 동시 공격을 하도록 시각을 맞춘다 (예: 박쥐 3마리의 동시 돌진).
## 첫 멤버의 행동 조각이 make_pack_attack()으로 규칙(PackAttack)을 만들고, 모든 멤버의 행동 조각에 join_pack()으로 나눠 준다.
## 동시 공격을 지원하지 않는 행동 조각이면 아무것도 하지 않는다.
## 멤버가 죽어 사라지면 남은 멤버끼리 계속한다 (싸우는 멤버 수가 모자라면 규칙이 동시 공격을 멈춘다).
## 싸우는 멤버들에게는 대상 주위의 자리 번호를 나눠 준다 (3마리면 120도씩). 줄어들면 남은 멤버끼리 다시 나눈다.

## 무리에 속한 몬스터들
@export var members: Array[NodePath] = []

var _pack: PackAttack
var _monsters: Array[Monster] = []
var _set_up: bool = false
## 무리 공동 대상 규칙
var _aggro: PackAggro = PackAggro.new()
## 멤버마다 지난 프레임에 스스로 노리던 대상 (없다가 생기면 어그로로 본다)
var _last_own_targets: Dictionary = {}
## 이번 프레임에 멤버를 때린 쪽들 (순서대로, 마지막이 가장 최근)
var _hits: Array[Node2D] = []
## 함께 포기하고 돌아가는 중인지
var _returning: bool = false
## 이번 싸움에서 자리의 기준 각도를 정했는지 (싸우는 멤버가 없어지면 다시 정한다)
var _formation_set: bool = false


## 코드로 무리를 만들 때 (밸런스 측정 등). 트리에 넣기 전에 부른다.
func set_members(monsters: Array[Monster]) -> void:
	_monsters = monsters
	members.clear()


## 테스트·측정용: 공유 규칙 (멤버가 동시 공격을 지원하지 않으면 null)
func get_pack_attack() -> PackAttack:
	return _pack


func _physics_process(delta: float) -> void:
	# 몬스터의 행동 조각은 몬스터의 _ready에서 만들어지므로, 첫 물리 프레임에 묶는다.
	if not _set_up:
		_set_up = true
		_bind()
	_share_targets()
	if _pack == null:
		return
	var fighting: Array[Monster] = []
	var all_ready: bool = true
	for monster: Monster in _alive_members():
		if monster.get_target() == null:
			monster.get_behavior().set_pack_slot(0, 0, [] as Array[Vector2])
			continue
		fighting.append(monster)
		if not monster.get_behavior().can_join_pack_attack():
			all_ready = false
	_assign_slots(fighting)
	_pack.update(delta, fighting.size(), all_ready)


## 싸우는 멤버들에게 대상 주위의 자리를 나눠 준다. 처음 싸움에 들어갈 때는 첫 멤버가 있는 쪽을 기준으로 삼는다.
func _assign_slots(fighting: Array[Monster]) -> void:
	if fighting.is_empty():
		_formation_set = false
		return
	var angles: Array[float] = []
	for monster: Monster in fighting:
		angles.append((monster.global_position - monster.get_target().global_position).angle())
	if not _formation_set:
		_formation_set = true
		_pack.set_formation_angle(angles[0])
	var slots: Array[int] = _pack.assign_slots(angles)
	for i: int in fighting.size():
		var mates: Array[Vector2] = []
		for other: Monster in fighting:
			if other != fighting[i]:
				mates.append(other.global_position)
		fighting[i].get_behavior().set_pack_slot(slots[i], fighting.size(), mates)


## 무리는 함께 싸운다 (PackAggro): 한 멤버라도 어그로가 끌리면(맞음, 또는 대상이 없다가 새로 감지함)
## 그 대상이 무리 대상이 되고, 모든 멤버가 자기 판단과 상관없이 무리 대상을 노린다. 가장 최근 어그로가 이긴다.
## 멤버 아무도 무리 대상을 원하지 않게 되면(Monster.wants_pack_target) 무리가 함께 포기하고 각자 시작한 자리로 돌아간다.
func _share_targets() -> void:
	var alive: Array[Monster] = _alive_members()
	# 함께 포기하고 돌아가는 중에는, 모두 다 돌아갈 때까지 어그로를 받지 않는다 (몬스터 타게팅의 돌아가기 규칙과 같다).
	if _returning:
		_returning = alive.any(func(monster: Monster) -> bool: return monster.get_aggro().state == Aggro.State.RETURNING)
		_hits.clear()
		for monster: Monster in alive:
			_last_own_targets[monster] = null
		return
	for monster: Monster in alive:
		var own: Node2D = monster.get_own_target()
		var last: Variant = _last_own_targets.get(monster)
		if own != null and not is_instance_valid(last):
			_aggro.on_aggro(own)
		_last_own_targets[monster] = own
	for source: Node2D in _hits:
		if is_instance_valid(source) and not source.is_queued_for_deletion():
			_aggro.on_aggro(source)
	_hits.clear()
	_aggro.resolve()
	var target: Node2D = _aggro.target as Node2D if is_instance_valid(_aggro.target) else null
	if _aggro.target != null and (target == null or target.is_queued_for_deletion()):
		_give_up(alive)
		return
	if target == null:
		return
	for monster: Monster in alive:
		monster.set_pack_target(target)
	if not alive.any(func(monster: Monster) -> bool: return monster.wants_pack_target(target)):
		_give_up(alive)


## 무리가 함께 포기한다. 무리 대상을 따르던 멤버는 각자 무리 싸움을 시작한 자리로 돌아간다.
func _give_up(alive: Array[Monster]) -> void:
	_aggro.give_up()
	for monster: Monster in alive:
		monster.return_home()
	_last_own_targets.clear()
	_returning = true


func _on_member_hit(source: Node2D) -> void:
	_hits.append(source)


## 테스트용: 무리 대상 (없으면 null)
func get_pack_target() -> Node2D:
	return _aggro.target as Node2D if is_instance_valid(_aggro.target) else null


func _alive_members() -> Array[Monster]:
	var alive: Array[Monster] = []
	for monster: Monster in _monsters:
		if is_instance_valid(monster) and not monster.is_queued_for_deletion() and monster.health > 0.0:
			alive.append(monster)
	return alive


func _bind() -> void:
	for path: NodePath in members:
		var monster: Monster = get_node_or_null(path) as Monster
		if monster != null:
			_monsters.append(monster)
	if _monsters.is_empty():
		return
	for monster: Monster in _monsters:
		monster.hit_by.connect(_on_member_hit)
	_pack = _monsters[0].get_behavior().make_pack_attack()
	if _pack == null:
		return
	for monster: Monster in _monsters:
		monster.get_behavior().join_pack(_pack)
