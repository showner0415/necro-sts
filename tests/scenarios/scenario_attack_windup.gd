extends ScenarioTest
## 시나리오: 기본 공격의 선딜레이와, 다른 키를 누른 채 공격하기. 거점(몬스터 없음)에서 한다.
## 1. 공격 버튼을 짧게 누르면(같은 프레임에 누르고 뗌) 선딜레이 전에는 탄이 없고, 지난 뒤에 하나 생긴다
## 2. 선딜레이 중에 마우스를 옮기면 옮긴 쪽으로 나간다 (누른 순간의 쪽이 아니다)
## 3. 선딜레이 중에 공격 버튼을 또 누르면 무시한다 (예약하지 않아 탄은 하나뿐)
## 4. 이동키(한 방향·대각선)나 다른 키(Shift, Ctrl, 숫자키)를 누른 채 공격해도 탄이 나가고, 선딜레이 중에 걸어도 취소되지 않는다
## 키는 실제 키보드처럼 키 이벤트(press_key)로 누른다 (press_moves는 입력 동작을 바로 누르므로 키 이벤트 경로를 거치지 않는다)

const AIM_DISTANCE: float = 100.0
## 선딜레이가 끝나기 전·후에 보는 여유 (프레임). 입력 이벤트가 전달되는 데 한 프레임쯤 걸릴 수 있다
const MARGIN_FRAMES: int = 2
## 단계 사이에 탄이 사라지고 상태가 가라앉기를 기다리는 시간 (프레임)
const SETTLE_FRAMES: int = 60
## 이동키를 누르고 걷기 시작한 뒤 공격하기까지 (프레임)
const WALK_BEFORE_FRAMES: int = 10
## 2단계: 누른 뒤 마우스를 옮기기까지 (프레임)
const MOVE_AIM_AFTER_FRAMES: int = 5
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
var _windup_frames: int = 0
## 생긴 탄 (child_entered_tree로 센다. 탄은 날아가다 사라지므로 개수를 직접 세지 않는다)
var _bolts: Array[Bolt] = []


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_necromancer.get_parent().child_entered_tree.connect(_on_child_added)
	_windup_frames = roundi(_necromancer.attack.windup * Engine.physics_ticks_per_second)
	await wait_frames(SETTLE_FRAMES)
	if not await _check_windup():
		return
	if not await _check_aim_moved():
		return
	if not await _check_repress_ignored():
		return
	if not await _check_keys_held():
		return
	finish(true)


func _on_child_added(node: Node) -> void:
	if node is Bolt:
		_bolts.append(node)


## 1. 짧게 누름 → 선딜레이 전에는 탄 없음, 지나면 하나
func _check_windup() -> bool:
	aim_mouse_at(_necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE)
	await wait_frames(1)
	var before: int = _bolts.size()
	press_mouse(true)
	press_mouse(false)
	await wait_frames(_windup_frames - MARGIN_FRAMES)
	var early: int = _bolts.size() - before
	var winding: bool = _necromancer.is_winding_up()
	await wait_frames(MARGIN_FRAMES * 2)
	var late: int = _bolts.size() - before
	await wait_frames(SETTLE_FRAMES)
	var later: int = _bolts.size() - before
	var evidence: String = "선딜레이 %.2f초(%d프레임). 누르고 %d프레임 뒤 탄 %d개(선딜레이 중 %s), %d프레임 뒤 %d개, 1초 더 지나 %d개 (같은 프레임에 누르고 뗌)" % [
		_necromancer.attack.windup, _windup_frames, _windup_frames - MARGIN_FRAMES, early, winding, _windup_frames + MARGIN_FRAMES, late, later]
	if early == 0 and winding and late == 1 and later == 1:
		pass_step("선딜레이 뒤에 탄 하나", evidence)
		return true
	fail_step("선딜레이 뒤에 탄 하나", evidence)
	return false


## 2. 누른 뒤 선딜레이 중에 마우스를 옮기면 옮긴 쪽으로 나간다
func _check_aim_moved() -> bool:
	var center: Vector2 = _necromancer.get_body_center()
	aim_mouse_at(center + Vector2.RIGHT * AIM_DISTANCE)
	await wait_frames(1)
	var before: int = _bolts.size()
	press_mouse(true)
	press_mouse(false)
	await wait_frames(MOVE_AIM_AFTER_FRAMES)
	var moved_aim: Vector2 = _necromancer.get_body_center() + Vector2(-1, 1).normalized() * AIM_DISTANCE
	aim_mouse_at(moved_aim)
	await wait_frames(_windup_frames + MARGIN_FRAMES)
	var count: int = _bolts.size() - before
	var bolt: Bolt = _bolts.back() if count > 0 else null
	var wanted: Vector2 = Vector2(-1, 1).normalized()
	var angle: float = rad_to_deg(absf(bolt.direction.angle_to(wanted))) if bolt != null else 180.0
	var evidence: String = "누를 때 동쪽, %d프레임 뒤 남서쪽으로 옮김. 탄 %d개, 탄 방향 %s, 남서쪽과 %.1f도 차이 (동쪽과 %.1f도)" % [
		MOVE_AIM_AFTER_FRAMES, count, bolt.direction if bolt != null else Vector2.ZERO, angle, rad_to_deg(absf(bolt.direction.angle_to(Vector2.RIGHT))) if bolt != null else 0.0]
	await wait_frames(SETTLE_FRAMES)
	if count == 1 and angle <= DIRECTION_TOLERANCE_DEGREES:
		pass_step("선딜레이가 끝난 순간의 마우스 쪽으로 나감", evidence)
		return true
	fail_step("선딜레이가 끝난 순간의 마우스 쪽으로 나감", evidence)
	return false


## 3. 선딜레이 중에 또 누르면 무시: 두 번째 누름에서 선딜레이를 다시 시작하지도, 예약하지도 않는다
func _check_repress_ignored() -> bool:
	aim_mouse_at(_necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE)
	await wait_frames(1)
	var before: int = _bolts.size()
	press_mouse(true)
	press_mouse(false)
	await wait_frames(MOVE_AIM_AFTER_FRAMES)
	press_mouse(true)
	press_mouse(false)
	await wait_frames(_windup_frames - MOVE_AIM_AFTER_FRAMES + MARGIN_FRAMES)
	var first: int = _bolts.size() - before
	await wait_frames(_windup_frames * 2)
	var total: int = _bolts.size() - before
	var evidence: String = "누르고 %d프레임 뒤 다시 누름. 첫 선딜레이가 끝날 때 탄 %d개, 선딜레이 두 번만큼 더 지나 %d개, 지금 선딜레이 중 %s" % [
		MOVE_AIM_AFTER_FRAMES, first, total, _necromancer.is_winding_up()]
	await wait_frames(SETTLE_FRAMES)
	if first == 1 and total == 1:
		pass_step("선딜레이 중에 또 누르면 무시", evidence)
		return true
	fail_step("선딜레이 중에 또 누르면 무시", evidence)
	return false


## 4. 이동키·다른 키를 누른 채 공격해도 탄이 나가고, 걸어도 선딜레이가 취소되지 않는다
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
		await wait_frames(_windup_frames + MARGIN_FRAMES)
		var count: int = _bolts.size() - before
		var walked: float = _necromancer.global_position.distance_to(start)
		for key: Key in keys:
			press_key(key, false)
		var names: PackedStringArray = []
		for key: Key in keys:
			names.append(OS.get_keycode_string(key))
		var moves: bool = keys.any(func(key: Key) -> bool: return [KEY_W, KEY_A, KEY_S, KEY_D].has(key))
		# 이동키가 있으면 선딜레이 동안 걸었어야 한다 (벽에 막히지 않을 만큼만 걷는다)
		var ok: bool = count == 1 and (walked > 1.0 if moves else true)
		all_ok = all_ok and ok
		lines.append("%s: 탄 %d개, 선딜레이 동안 %.0fpx 걸음%s" % ["+".join(names), count, walked, "" if ok else " ← 틀림"])
		await wait_frames(SETTLE_FRAMES)
		# 걷다 벽에 붙지 않게 처음 자리 근처로 되돌린다
		_necromancer.global_position = home
	var evidence: String = ", ".join(lines)
	if all_ok:
		pass_step("다른 키를 누른 채 공격", evidence)
		return true
	fail_step("다른 키를 누른 채 공격", evidence)
	return false
