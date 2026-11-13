extends ScenarioTest
## 시나리오: 기본 공격의 입력 (선딜레이 없음)과, 다른 키를 누른 채 공격하기. 거점(몬스터 없음)에서 한다.
## 1. 공격 버튼을 짧게 누르면(같은 프레임에 누르고 뗌) 바로 탄이 하나 나가고, 누른 순간의 마우스 쪽으로 간다
## 2. 후딜레이 중에 공격 버튼을 또 누르면 무시한다 (예약하지 않아 탄은 하나뿐)
## 3. 누르고 있으면 후딜레이(attack.cooldown)마다 이어서 쏜다
## 4. 이동키(한 방향·대각선)나 다른 키(Shift, Ctrl, 숫자키)를 누른 채 공격해도 탄이 나가고, 쏘면서 걸을 수 있다
## 키는 실제 키보드처럼 키 이벤트(press_key)로 누른다 (press_moves는 입력 동작을 바로 누르므로 키 이벤트 경로를 거치지 않는다)

const AIM_DISTANCE: float = 100.0
## 탄이 나왔는지 보기 전에 기다리는 여유 (프레임). 입력 이벤트가 전달되는 데 한 프레임쯤 걸릴 수 있다
const MARGIN_FRAMES: int = 2
## 단계 사이에 탄이 사라지고 상태가 가라앉기를 기다리는 시간 (프레임). 후딜레이보다 길어야 한다
const SETTLE_FRAMES: int = 60
## 이동키를 누르고 걷기 시작한 뒤 공격하기까지, 공격한 뒤 걸음을 재기까지 (프레임)
const WALK_BEFORE_FRAMES: int = 10
## 2단계: 쏜 뒤 다시 누르기까지 (프레임)
const REPRESS_AFTER_FRAMES: int = 5
## 3단계: 누르고 있는 동안 나와야 하는 탄 수 (첫 탄 + 후딜레이마다)
const HOLD_SHOTS: int = 4
## 탄 방향이 조준 방향과 이 각도 안이면 같은 쪽으로 본다 (도)
const DIRECTION_TOLERANCE_DEGREES: float = 3.0
## 4단계에서 누른 채 공격할 키들. 이동키는 move_up(W)·move_down(S)·move_left(A)·move_right(D)
const KEY_CASES: Array = [
	[KEY_W],
	[KEY_D],
	[KEY_W, KEY_D],
	[KEY_S, KEY_A],
	[KEY_W, KEY_A],
	[KEY_S, KEY_D],
	[KEY_SHIFT],
	[KEY_SHIFT, KEY_W, KEY_D],
	[KEY_CTRL, KEY_S],
	[KEY_1, KEY_A],
]

var _necromancer: Necromancer
var _cooldown_frames: int = 0
## 생긴 탄 (child_entered_tree로 센다. 탄은 날아가다 사라지므로 개수를 직접 세지 않는다)
var _bolts: Array[Bolt] = []


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_necromancer.get_parent().child_entered_tree.connect(_on_child_added)
	_cooldown_frames = roundi(_necromancer.attack.cooldown * Engine.physics_ticks_per_second)
	await wait_frames(SETTLE_FRAMES)
	if not await _check_click():
		return
	if not await _check_repress_ignored():
		return
	if not await _check_hold():
		return
	if not await _check_keys_held():
		return
	finish(true)


func _on_child_added(node: Node) -> void:
	if node is Bolt:
		_bolts.append(node)


## 1. 짧게 누름 → 바로 탄 하나, 누른 순간의 마우스 쪽
func _check_click() -> bool:
	aim_mouse_at(_necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE)
	await wait_frames(1)
	var before: int = _bolts.size()
	press_mouse(true)
	press_mouse(false)
	await wait_frames(MARGIN_FRAMES)
	var soon: int = _bolts.size() - before
	var bolt: Bolt = _bolts.back() if soon > 0 else null
	var angle: float = rad_to_deg(absf(bolt.direction.angle_to(Vector2.RIGHT))) if bolt != null else 180.0
	await wait_frames(SETTLE_FRAMES)
	var later: int = _bolts.size() - before
	var evidence: String = "누르고 %d프레임 뒤 탄 %d개 (동쪽과 %.1f도 차이), 1초 더 지나 %d개 (같은 프레임에 누르고 뗌)" % [MARGIN_FRAMES, soon, angle, later]
	if soon == 1 and later == 1 and angle <= DIRECTION_TOLERANCE_DEGREES:
		pass_step("짧게 누르면 바로 탄 하나", evidence)
		return true
	fail_step("짧게 누르면 바로 탄 하나", evidence)
	return false


## 2. 후딜레이 중에 또 누르면 무시: 후딜레이가 끝나도 탄이 더 나가지 않는다
func _check_repress_ignored() -> bool:
	aim_mouse_at(_necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE)
	await wait_frames(1)
	var before: int = _bolts.size()
	press_mouse(true)
	press_mouse(false)
	await wait_frames(REPRESS_AFTER_FRAMES)
	press_mouse(true)
	press_mouse(false)
	await wait_frames(_cooldown_frames + MARGIN_FRAMES * 2)
	var total: int = _bolts.size() - before
	var evidence: String = "쏘고 %d프레임 뒤(후딜레이 %d프레임 중) 다시 누름. 후딜레이가 끝나고 %d프레임 더 지나 탄 %d개" % [
		REPRESS_AFTER_FRAMES, _cooldown_frames, MARGIN_FRAMES * 2, total]
	await wait_frames(SETTLE_FRAMES)
	if total == 1:
		pass_step("후딜레이 중에 또 누르면 무시", evidence)
		return true
	fail_step("후딜레이 중에 또 누르면 무시", evidence)
	return false


## 3. 누르고 있으면 후딜레이마다 이어서 쏜다
func _check_hold() -> bool:
	aim_mouse_at(_necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE)
	await wait_frames(1)
	var before: int = _bolts.size()
	var frames: Array[int] = []
	press_mouse(true)
	var hold_frames: int = _cooldown_frames * (HOLD_SHOTS - 1) + MARGIN_FRAMES * HOLD_SHOTS
	var seen: int = 0
	for frame: int in hold_frames:
		await wait_frames(1)
		while _bolts.size() - before > seen:
			seen += 1
			frames.append(frame)
	press_mouse(false)
	await wait_frames(SETTLE_FRAMES)
	var total: int = _bolts.size() - before
	var gaps: PackedStringArray = []
	for i: int in range(1, frames.size()):
		gaps.append(str(frames[i] - frames[i - 1]))
	var evidence: String = "%d프레임 누르고 있음. 탄 %d개, 탄 사이 프레임 [%s] (후딜레이 %d프레임), 뗀 뒤 1초 지나 %d개" % [
		hold_frames, seen, ", ".join(gaps), _cooldown_frames, total]
	var gaps_ok: bool = true
	for gap: String in gaps:
		gaps_ok = gaps_ok and absi(int(gap) - _cooldown_frames) <= 1
	if seen == HOLD_SHOTS and total == HOLD_SHOTS and gaps_ok:
		pass_step("누르고 있으면 후딜레이마다 쏨", evidence)
		return true
	fail_step("누르고 있으면 후딜레이마다 쏨", evidence)
	return false


## 4. 이동키·다른 키를 누른 채 공격해도 탄이 나가고, 쏘면서 걸을 수 있다
func _check_keys_held() -> bool:
	var lines: PackedStringArray = []
	var all_ok: bool = true
	var home: Vector2 = _necromancer.global_position
	for keys: Array in KEY_CASES:
		for key: Key in keys:
			press_key(key, true)
		await wait_frames(WALK_BEFORE_FRAMES)
		aim_mouse_at(_necromancer.get_body_center() + Vector2.UP * AIM_DISTANCE)
		await wait_frames(1)
		var before: int = _bolts.size()
		var start: Vector2 = _necromancer.global_position
		press_mouse(true)
		press_mouse(false)
		await wait_frames(WALK_BEFORE_FRAMES)
		var count: int = _bolts.size() - before
		var walked: float = _necromancer.global_position.distance_to(start)
		for key: Key in keys:
			press_key(key, false)
		var names: PackedStringArray = []
		for key: Key in keys:
			names.append(OS.get_keycode_string(key))
		var moves: bool = keys.any(func(key: Key) -> bool: return [KEY_W, KEY_A, KEY_S, KEY_D].has(key))
		# 이동키가 있으면 쏜 뒤에도 걸었어야 한다 (벽에 막히지 않을 만큼만 걷는다)
		var ok: bool = count == 1 and (walked > 1.0 if moves else true)
		all_ok = all_ok and ok
		lines.append("%s: 탄 %d개, 쏜 뒤 %d프레임 동안 %.0fpx 걸음%s" % ["+".join(names), count, WALK_BEFORE_FRAMES, walked, "" if ok else " ← 틀림"])
		await wait_frames(SETTLE_FRAMES)
		# 걷다 벽에 붙지 않게 처음 자리 근처로 되돌린다
		_necromancer.global_position = home
	var evidence: String = ", ".join(lines)
	if all_ok:
		pass_step("다른 키를 누른 채 공격", evidence)
		return true
	fail_step("다른 키를 누른 채 공격", evidence)
	return false
