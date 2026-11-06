class_name PackAttack
extends RefCounted
## 무리 동시 공격의 시각을 맞추는 규칙. 무리(MonsterPack)가 하나 만들어 멤버들의 행동 조각에 나눠 준다.
## - 싸우는 멤버(대상이 있는 멤버)가 min_members 이상인 동안 시간을 재서, interval초마다 동시 공격 예고를 시작한다.
##   싸우는 멤버가 그보다 적어지면 시간을 처음으로 돌린다
## - 시작할 때가 되어도 멤버 중 하나라도 자기 공격(예고·돌진·물러나기) 중이면 모두 끝날 때까지 기다린다
## - 시작할 때가 되면(is_assembling) 멤버들이 자기 자리로 모인다. 멤버가 모두 자리에 오면 예고를 시작하고,
##   assemble_timeout초가 지나도 못 모이면 자리와 상관없이 시작한다 (is_assembly_overdue)
## - 예고는 windup_time초다. 끝나기 lock_time초 전에 돌진 방향이 고정되고, 예고가 끝나면 모두 함께 돌진한다
## 멤버(행동 조각)는 is_winding_up()·get_round()·is_direction_locked()를 읽어 따라 한다.
## 노드에 의존하지 않으므로 씬 없이 따로 확인할 수 있다.

var interval: float
var windup_time: float
var lock_time: float
var min_members: int
## 무리의 자리(구역)들이 한 바퀴 도는 시간 (초). 0이면 돌지 않는다.
var formation_turn_time: float
## 동시 공격 때가 되어 자리를 잡는 데 기다리는 최대 시간 (초)
var assemble_timeout: float = INF

## 동시 공격 예고 중인지
var _winding_up: bool = false
## 지난 동시 공격 뒤 흐른 시간 (싸우는 멤버가 모자라면 0으로)
var _timer: float = 0.0
## 예고를 시작하고 흐른 시간
var _elapsed: float = 0.0
## 지금까지 시작한 동시 공격 수. 멤버는 이 값으로 이번 예고에 이미 들어갔는지 안다.
var _round: int = 0
## 무리 자리의 기준 각도 (라디안). 멤버의 자리 가운데 = 이 각도 + 번호 × 360°/마리 수
var _formation_angle: float = 0.0


func _init(attack_interval: float, windup: float, lock: float, members_needed: int, turn_time: float = 0.0) -> void:
	interval = attack_interval
	windup_time = windup
	lock_time = lock
	min_members = members_needed
	formation_turn_time = turn_time


## 물리 프레임마다 한 번 부른다. engaged: 대상이 있는 살아 있는 멤버 수,
## all_ready: 그 멤버들이 모두 동시 공격에 들어갈 수 있는지 (자기 공격 중이 아님).
## 자리의 기준 각도는 동시 공격과 상관없이 계속 돈다.
func update(delta: float, engaged: int, all_ready: bool) -> void:
	if formation_turn_time > 0.0:
		_formation_angle = wrapf(_formation_angle + delta * TAU / formation_turn_time, -PI, PI)
	if _winding_up:
		_elapsed += delta
		if _elapsed >= windup_time:
			_winding_up = false
		return
	if engaged < min_members:
		_timer = 0.0
		return
	_timer += delta
	if _timer >= interval and all_ready:
		_timer = 0.0
		_elapsed = 0.0
		_winding_up = true
		_round += 1


func is_winding_up() -> bool:
	return _winding_up


## 지금(또는 마지막) 동시 공격의 번호. 1부터 센다.
func get_round() -> int:
	return _round


## 예고 중이고 방향을 고정할 때가 되었는지 (예고가 끝나기 lock_time초 전부터)
func is_direction_locked() -> bool:
	return _winding_up and _elapsed >= windup_time - lock_time


## 동시 공격할 때가 되어 멤버들이 자리를 잡는 중인지 (예고 시작 전). 멤버는 이때 자기 자리 가운데로 간다.
func is_assembling() -> bool:
	return not _winding_up and _timer >= interval


## 자리 잡기를 assemble_timeout초 넘게 기다렸는지. 그러면 멤버는 자리와 상관없이 들어간다.
func is_assembly_overdue() -> bool:
	return is_assembling() and _timer - interval >= assemble_timeout


func get_formation_angle() -> float:
	return _formation_angle


## 처음 자리를 잡을 때 기준 각도를 맞춘다 (멤버가 이미 있는 쪽에서 시작하게).
func set_formation_angle(angle: float) -> void:
	_formation_angle = wrapf(angle, -PI, PI)


## 멤버들이 지금 대상 주위에 있는 각도(angles)로, 서로 순서를 지키며 가장 덜 움직이도록 자리 번호를 정한다.
## 돌려주는 값: angles와 같은 순서의 자리 번호 (0부터). 기준 각도에서 시계 방향 순서대로 번호를 붙인다.
func assign_slots(angles: Array[float]) -> Array[int]:
	var count: int = angles.size()
	var order: Array[int] = []
	for i: int in count:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return wrapf(angles[a] - _formation_angle, 0.0, TAU) < wrapf(angles[b] - _formation_angle, 0.0, TAU))
	# 순서는 각도 순서 그대로 두고, 첫 번호를 몇 칸 돌릴지는 모두가 움직이는 각도의 합이 가장 작은 쪽으로 고른다.
	var best_shift: int = 0
	var best_cost: float = INF
	for shift: int in count:
		var cost: float = 0.0
		for rank: int in count:
			var slot_center: float = _formation_angle + ((rank + shift) % count) * TAU / count
			cost += absf(wrapf(angles[order[rank]] - slot_center, -PI, PI))
		if cost < best_cost:
			best_cost = cost
			best_shift = shift
	var slots: Array[int] = []
	slots.resize(count)
	for rank: int in count:
		slots[order[rank]] = (rank + best_shift) % count
	return slots


## 다음 동시 공격까지 남은 시간 (예고 중이면 0)
func get_time_until_next() -> float:
	return 0.0 if _winding_up else maxf(interval - _timer, 0.0)
