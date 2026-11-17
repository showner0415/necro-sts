extends TestCase
## MonsterPack(무리 노드) 단위 테스트: 첫 물리 프레임 전에 무리원이 지워져도, 무리가 지워진 몬스터를 읽지 않는다.
## 3D 화면 검사(check_vision_3d.gd, check_wall_occlusion.gd)가 몬스터를 free()한 뒤 무리가 묶으면서 SCRIPT ERROR가 났다 (2026-11-16).
## 단위 테스트는 씬 트리가 시작하기 전에 돌므로 _physics_process를 직접 부른다.

const FRAME: float = 1.0 / 60.0
const MEMBER_COUNT: int = 2

var _pack: MonsterPack


func before_each() -> void:
	_pack = MonsterPack.new()


func after_each() -> void:
	_pack.free()


func test_members_freed_before_first_frame_are_dropped() -> void:
	var monsters: Array[Monster] = []
	for i: int in MEMBER_COUNT:
		monsters.append(Monster.new())
	_pack.set_members(monsters)
	for monster: Monster in monsters:
		monster.free()
	# 첫 프레임에 묶고, 다음 프레임도 돈다. 지워진 무리원을 읽으면 SCRIPT ERROR가 난다.
	_pack._physics_process(FRAME)
	_pack._physics_process(FRAME)
	# 고치기 전에는 지워진 무리원 둘이 그대로 남아 있었다.
	assert_eq((_pack.get("_monsters") as Array).size(), 0, "지워진 무리원은 묶을 때 빠짐")
	assert_eq(_pack.get_pack_attack(), null, "묶을 무리원이 없으면 공유 공격 규칙도 없음")
