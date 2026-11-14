class_name MonsterPack
extends Node
## 몬스터 무리. members의 몬스터들이 함께 싸운다. 다른 무리끼리는 돕지 않는다. 무리 규칙은 첫 멤버의 데이터로 정한다:
## - 대상 하나를 함께 노리는 무리 (박쥐, MonsterData.pack_one_target): 한 멤버라도 어그로가 끌리면 무리 전체가 그 대상을 노린다 (PackAggro)
## - 경보를 쓰는 무리 (그 밖의 무리): 무리원이 맞거나 적을 감지하면 신호 뒤 경보가 나고, 네크로맨서 편 전체 중 무리원마다 가장 가까운 적을 노린다 (PackAlarm)
## 둘 다 무리원 모두가 종별 추격 포기 조건(ChaseClock)을 넘으면 함께 포기해 그 자리에서 평소 행동을 한다 (돌아가지 않는다).
## 함께 동시 공격을 하도록 시각을 맞춘다 (예: 박쥐 3마리의 동시 돌진).
## 첫 멤버의 행동 조각이 make_pack_attack()으로 규칙(PackAttack)을 만들고, 모든 멤버의 행동 조각에 join_pack()으로 나눠 준다.
## 동시 공격을 지원하지 않는 행동 조각이면 아무것도 하지 않는다.
## 멤버가 죽어 사라지면 남은 멤버끼리 계속한다 (싸우는 멤버 수가 모자라면 규칙이 동시 공격을 멈춘다).
## 싸우는 멤버들에게는 대상 주위의 자리 번호를 나눠 준다 (3마리면 120도씩). 줄어들면 남은 멤버끼리 다시 나눈다.

## 무리에 속한 몬스터들
@export var members: Array[NodePath] = []
## 경보 중에 무리원마다 적을 보는(벽 광선 검사) 간격 (프레임). 무리원마다 엇갈린 프레임에 본다
@export var sight_check_interval: int = 3

@export_group("함께 배회")
## 무리원이 배회 기준점에서 벗어나도 되는 거리 (픽셀, 임시값 64 = 2칸. 사용자 결정 2026-11-14). 밖이면 기준점 쪽으로 돌아온다
@export var wander_radius: float = 64.0
## 기준점이 방향을 새로 고르는 간격 (초)
@export var wander_anchor_interval: float = 3.0
## 기준점이 방향을 고를 때 멈춰 있기로 할 확률 (0~1)
@export_range(0.0, 1.0) var wander_anchor_rest_chance: float = 0.3
## 기준점이 움직이는 속도: 무리원 중 가장 느린 배회 속도에 곱한다 (1보다 작아야 무리원이 따라온다)
@export var wander_anchor_speed_ratio: float = 0.6

@export_group("디버그 표시")
## 무리 디버그 표시(무리 소속, 경보 상태)를 켜고 끄는 키 (사용자 결정 2026-11-14). 개발 빌드에서만 듣는다
@export var debug_toggle_key: Key = KEY_F3
## 이 무리의 디버그 색. 투명(알파 0)이면 DEBUG_COLORS에서 무리 순서대로 고른다
@export var debug_color: Color = Color(0, 0, 0, 0)

## _sight에 두는 표시: 벽이 가리지 않음, 그리고 그 무리원의 감지 범위 안
const SEEN: int = 1
const IN_DETECT: int = 2
## 무리 디버그 색 (팔레트 안의 색: 주황, 파랑, 초록, 보라, 노랑, 청록)
const DEBUG_COLORS: Array[Color] = [Color("f77622"), Color("0099db"), Color("63c74d"), Color("b55088"), Color("feae34"), Color("2ce8f5")]

## 무리 디버그 표시가 켜져 있는지 (모든 무리가 함께 쓴다)
static var _debug_visible: bool = false
## 디버그 키를 마지막으로 처리한 프레임 (무리가 여럿이어도 한 번 누름에 한 번만 바꾼다)
static var _debug_toggled_frame: int = -1

var _pack: PackAttack
var _monsters: Array[Monster] = []
## 무리 대장 (계획 6a). 살아 있는 동안 무리원 공격력에 대장 배율을 곱하고, 죽으면 바로 되돌린다
var _leader: Monster
var _leader_active: bool = false
var _set_up: bool = false
## 대상 하나를 함께 노리는 무리인지 (첫 멤버의 MonsterData.pack_one_target)
var _one_target: bool = false
## 대상 하나를 함께 노리는 무리의 공동 대상 규칙
var _aggro: PackAggro = PackAggro.new()
## 경보를 쓰는 무리의 경보 규칙
var _alarm: PackAlarm = PackAlarm.new()
## 경보 중에 무리원마다 본 것: 무리원 → {적: SEEN | IN_DETECT}
var _sight: Dictionary = {}
## 멤버마다 지난 프레임에 스스로 노리던 대상 (없다가 생기면 어그로·감지로 본다)
var _last_own_targets: Dictionary = {}
## 이번 프레임에 맞은 멤버와 때린 쪽: [멤버, 때린 쪽] (순서대로, 마지막이 가장 최근)
var _hits: Array[Array] = []
## 무리가 쫓다가 포기하는 조건을 재는 시계 (무리원 모두의 눈을 합쳐서 잰다)
var _chase: ChaseClock = ChaseClock.new()
## 이번 싸움에서 자리의 기준 각도를 정했는지 (싸우는 멤버가 없어지면 다시 정한다)
var _formation_set: bool = false
## 경보를 쓰는 무리가 함께 배회하는 규칙 (대상 하나를 함께 노리는 무리는 null)
var _wander: PackWander


## 무리 디버그 표시가 켜져 있는지 (몬스터가 바닥 표시를 그릴 때 본다)
static func is_debug_visible() -> bool:
	return _debug_visible


## 테스트·디버그용: 무리 디버그 표시를 켜거나 끈다
static func set_debug_visible(visible: bool) -> void:
	_debug_visible = visible


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != debug_toggle_key or not OS.is_debug_build():
		return
	var frame: int = Engine.get_process_frames()
	if _debug_toggled_frame != frame:
		_debug_toggled_frame = frame
		_debug_visible = not _debug_visible
	get_viewport().set_input_as_handled()


## 코드로 무리를 만들 때 (밸런스 측정, 시나리오 등). 트리에 넣기 전에 부른다.
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
	_check_leader()
	var alive: Array[Monster] = _alive_members()
	if not alive.is_empty():
		if _one_target:
			_share_one_target(delta, alive)
		else:
			_run_alarm(delta, alive)
			# 경보 중이 아니면 함께 배회한다 (신호 중에도 다른 무리원은 아직 평소다).
			if _wander != null and not _alarm.is_alert():
				_wander.update(delta, _center(alive))
		_share_debug(alive)
	_hits.clear()
	if _pack == null:
		return
	var fighting: Array[Monster] = []
	var all_ready: bool = true
	for monster: Monster in alive:
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


## 대상 하나를 함께 노리는 무리 (박쥐): 한 멤버라도 어그로가 끌리면(맞음, 또는 대상이 없다가 새로 감지함)
## 그 대상이 무리 대상이 되고, 모든 멤버가 자기 판단과 상관없이 무리 대상을 노린다. 가장 최근 어그로가 이긴다.
## 무리원 하나라도 대상까지 벽이 가리지 않으면 무리가 본 것으로 친다.
func _share_one_target(delta: float, alive: Array[Monster]) -> void:
	for monster: Monster in alive:
		var own: Node2D = monster.get_own_target()
		var last: Variant = _last_own_targets.get(monster)
		if own != null and not is_instance_valid(last):
			_aggro.on_aggro(own)
		_last_own_targets[monster] = own
	var was_hit: bool = false
	for hit: Array in _hits:
		var source: Node2D = hit[1] as Node2D if is_instance_valid(hit[1]) else null
		if _is_alive_node(source):
			_aggro.on_aggro(source)
			was_hit = true
	# 대상이 새로 생기거나 바뀌면 포기 조건을 처음부터 잰다. 같은 대상에게 다시 맞으면 추격 시간만 다시 잰다.
	if _aggro.resolve():
		_chase.reset()
	elif was_hit:
		_chase.on_hit()
	var target: Node2D = _aggro.target as Node2D if is_instance_valid(_aggro.target) else null
	if _aggro.target != null and (target == null or target.is_queued_for_deletion()):
		_give_up(alive)
		return
	if target == null:
		return
	for monster: Monster in alive:
		monster.set_pack_target(target)
	var seen: bool = false
	var detected: bool = false
	for monster: Monster in alive:
		if not monster.can_see_point(target.global_position):
			continue
		seen = true
		if monster.global_position.distance_to(target.global_position) <= monster.data.detect_range:
			detected = true
			break
	_chase.update(delta, seen, detected)
	if alive.all(func(monster: Monster) -> bool: return _member_gives_up(monster, target)):
		_give_up(alive)


## 경보를 쓰는 무리 (PackAlarm, docs/game-design.md "몬스터 무리"):
## - 무리원이 맞거나 적을 감지하면, 그 무리원이 신호(멈춤·깜빡임)를 낸 뒤 무리 전체가 경보 상태가 된다
## - 경보 중에는 네크로맨서 편 전체(네크로맨서와 모든 언데드)가 적이고, 무리원마다 그중 가장 가까운 적을 노린다.
##   아무도 적을 못 봐도 길을 따라 적의 실제 위치로 쫓는다
## - 무리원이 본 것은 무리가 모은다 (추격 포기 조건의 "보는지"). 무리원마다 sight_check_interval프레임에 한 번씩 엇갈려 본다
## - 무리원 모두가 자기 종의 추격 포기 조건을 넘으면 함께 포기하고 그 자리에서 평소 행동을 한다
func _run_alarm(delta: float, alive: Array[Monster]) -> void:
	var was_alert: bool = _alarm.is_alert()
	var hit_by_enemy: bool = false
	for hit: Array in _hits:
		var member: Monster = hit[0] as Monster if is_instance_valid(hit[0]) else null
		var source: Node2D = hit[1] as Node2D if is_instance_valid(hit[1]) else null
		if member != null and _is_enemy(source):
			_alarm.trigger(member, member.data.alarm_signal_time)
			hit_by_enemy = true
	for monster: Monster in alive:
		var own: Node2D = monster.get_own_target()
		var last: Variant = _last_own_targets.get(monster)
		if own != null and not is_instance_valid(last):
			_alarm.trigger(monster, monster.data.alarm_signal_time)
		_last_own_targets[monster] = own
	if was_alert and hit_by_enemy:
		_chase.on_hit()
	# 신호를 내던 무리원이 죽었으면 바로 경보로 간다.
	if _alarm.state == PackAlarm.State.SIGNAL and not alive.has(_alarm.signaller):
		_alarm.end_signal()
	var became_alert: bool = _alarm.update(delta) or (not was_alert and _alarm.is_alert())
	for monster: Monster in alive:
		monster.set_alarm_signal(_alarm.is_signalling(monster))
	if not _alarm.is_alert():
		return
	if became_alert:
		_chase.reset()
		_sight.clear()
	var enemies: Array[Node2D] = _all_enemies()
	if enemies.is_empty():
		_give_up(alive)
		return
	_update_sight(alive, enemies, became_alert)
	var seen: bool = false
	var detected: bool = false
	for monster: Monster in alive:
		monster.set_pack_target(_nearest(monster, enemies))
		var looks: Dictionary = _sight.get(monster, {})
		for enemy: Node2D in enemies:
			var flags: int = looks.get(enemy, 0)
			seen = seen or (flags & SEEN) != 0
			detected = detected or (flags & IN_DETECT) != 0
	_chase.update(delta, seen, detected)
	if alive.all(func(monster: Monster) -> bool: return _member_gives_up(monster, _nearest(monster, enemies))):
		_give_up(alive)


## 무리원마다 sight_check_interval프레임에 한 번씩 엇갈려 적들을 본다 (every면 모두 지금 본다).
## 결과는 _sight에 둔다: 무리원 → {적: SEEN | IN_DETECT}.
func _update_sight(alive: Array[Monster], enemies: Array[Node2D], every: bool) -> void:
	var frame: int = Engine.get_physics_frames()
	var interval: int = maxi(sight_check_interval, 1)
	for i: int in alive.size():
		if not every and (i + frame) % interval != 0:
			continue
		var monster: Monster = alive[i]
		var looks: Dictionary = {}
		for enemy: Node2D in enemies:
			if not monster.can_see_point(enemy.global_position):
				continue
			var flags: int = SEEN
			if monster.global_position.distance_to(enemy.global_position) <= monster.data.detect_range:
				flags |= IN_DETECT
			looks[enemy] = flags
		_sight[monster] = looks


## 무리의 적이 될 수 있는 것들: 네크로맨서와 모든 언데드 (경보가 나면 네크로맨서 편 전체가 적이다)
func _all_enemies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"necromancer")
	nodes.append_array(get_tree().get_nodes_in_group(&"undead"))
	for node: Node in nodes:
		if node is Node2D and not node.is_queued_for_deletion():
			result.append(node as Node2D)
	return result


func _is_enemy(node: Node2D) -> bool:
	return _is_alive_node(node) and (node.is_in_group(&"necromancer") or node.is_in_group(&"undead"))


## 무리원들의 가운데 (발밑 좌표의 평균)
func _center(monsters: Array[Monster]) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for monster: Monster in monsters:
		if is_instance_valid(monster):
			sum += monster.global_position
			count += 1
	return sum / count if count > 0 else Vector2.ZERO


## 무리원마다 디버그 표시에 쓸 무리 정보를 넣어 준다 (표시가 꺼져 있어도 넣는다. 그리는 쪽이 켜졌는지 본다).
## 대상 하나를 함께 노리는 무리는 경보 상태가 없으므로 대상이 있으면 경보, 없으면 평소로 보인다.
func _share_debug(alive: Array[Monster]) -> void:
	for monster: Monster in alive:
		var state: int = _alarm.state
		if _one_target:
			state = PackAlarm.State.ALERT if monster.get_target() != null else PackAlarm.State.CALM
		var anchor: Vector2 = _wander.anchor if _wander != null else Vector2.ZERO
		var radius: float = _wander.radius if _wander != null and state != PackAlarm.State.ALERT else 0.0
		monster.set_pack_debug(debug_color, state, anchor, radius)


## 같은 부모 아래 무리(MonsterPack)들 가운데 이 무리가 몇 번째인지 (디버그 색을 무리 순서대로 고른다)
func _pack_order() -> int:
	var order: int = 0
	for sibling: Node in get_parent().get_children():
		if sibling == self:
			return order
		if sibling is MonsterPack:
			order += 1
	return order


## 테스트·디버그용: 함께 배회하는 기준점 (함께 배회하지 않는 무리면 null)
func get_wander() -> PackWander:
	return _wander


func _nearest(monster: Monster, enemies: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for enemy: Node2D in enemies:
		var distance: float = monster.global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## 이 멤버가 자기 종의 추격 포기 조건을 넘었는지 (target까지의 거리로 잰다)
func _member_gives_up(monster: Monster, target: Node2D) -> bool:
	var distance: float = monster.global_position.distance_to(target.global_position) if target != null else INF
	return _chase.gives_up(distance, monster.data.chase_attacker_limit, monster.data.chase_lost_time, monster.data.chase_time_limit)


## 무리가 함께 포기한다. 멤버는 돌아가지 않고 그 자리에서 평소 행동(배회)을 한다.
func _give_up(alive: Array[Monster]) -> void:
	_aggro.give_up()
	_alarm.give_up()
	_sight.clear()
	for monster: Monster in alive:
		monster.clear_pack_target()
		monster.set_alarm_signal(false)
	_last_own_targets.clear()
	# 포기한 자리(무리 가운데)에서 다시 함께 배회한다.
	if _wander != null:
		_wander.reset(_center(alive))


func _on_member_hit(source: Node2D, member: Monster) -> void:
	_hits.append([member, source])


## 테스트용: 무리 대상 (대상 하나를 함께 노리는 무리만. 없으면 null)
func get_pack_target() -> Node2D:
	return _aggro.target as Node2D if is_instance_valid(_aggro.target) else null


## 테스트·디버그용: 경보 상태 (경보를 쓰는 무리만, PackAlarm.State)
func get_alarm_state() -> PackAlarm.State:
	return _alarm.state


## 테스트·디버그용: 경보를 쓰는 무리인지 (false면 대상 하나를 함께 노린다)
func uses_alarm() -> bool:
	return not _one_target


func _alive_members() -> Array[Monster]:
	var alive: Array[Monster] = []
	for monster: Monster in _monsters:
		if is_instance_valid(monster) and not monster.is_queued_for_deletion() and monster.health > 0.0:
			alive.append(monster)
	return alive


func _is_alive_node(node: Node2D) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()


func _bind() -> void:
	for path: NodePath in members:
		var monster: Monster = get_node_or_null(path) as Monster
		if monster != null:
			_monsters.append(monster)
	if _monsters.is_empty():
		return
	_one_target = _monsters[0].data.pack_one_target
	if debug_color.a <= 0.0:
		debug_color = DEBUG_COLORS[_pack_order() % DEBUG_COLORS.size()]
	# 경보를 쓰는 무리는 함께 배회한다. 기준점은 무리 가운데에서 시작하고, 무리원 중 가장 느린 배회 속도보다 느리게 움직인다.
	if not _one_target:
		var slowest: float = INF
		for monster: Monster in _monsters:
			slowest = minf(slowest, monster.data.wander_speed)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = randi()
		_wander = PackWander.new(_center(_monsters), wander_radius, wander_anchor_interval, wander_anchor_rest_chance, slowest * wander_anchor_speed_ratio, rng)
		for monster: Monster in _monsters:
			monster.set_pack_wander(_wander)
	for monster: Monster in _monsters:
		monster.hit_by.connect(_on_member_hit.bind(monster))
	_pack = _monsters[0].get_behavior().make_pack_attack()
	if _pack == null:
		return
	for monster: Monster in _monsters:
		monster.get_behavior().join_pack(_pack)


## 무리 대장을 정한다 (무리 자리 PackSpawn이 무리를 만들 때). 대장이 살아 있는 동안 무리원 모두(대장 포함)의 공격력에 ratio를 곱한다.
func set_leader(leader: Monster, ratio: float) -> void:
	_leader = leader
	_leader_active = true
	for monster: Monster in _monsters:
		monster.damage_ratio = ratio


## 테스트·디버그용: 대장 (없거나 죽었으면 null)
func get_leader() -> Monster:
	return _leader if _leader_active else null


## 대장이 죽으면(사라지거나 체력 0) 강화를 바로 없앤다.
func _check_leader() -> void:
	if not _leader_active:
		return
	if is_instance_valid(_leader) and not _leader.is_queued_for_deletion() and _leader.health > 0.0:
		return
	_leader_active = false
	_leader = null
	for monster: Variant in _monsters:
		if is_instance_valid(monster):
			(monster as Monster).damage_ratio = 1.0
