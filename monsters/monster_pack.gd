class_name MonsterPack
extends Node2D
## 어그로를 공유하는 몬스터 무리. 지역 씬에서 몬스터들을 이 노드 아래에 둔다 (예: 박쥐 3마리).
## - 한 마리라도 직접 싸우는 중이면(감지 범위에 대상이 있거나 공격자를 쫓는 중) 무리 전체가 싸우는 중이다
## - 싸우는 중이면, 자기 대상이 없는 몬스터는 감지 범위와 상관없이 가장 가까운 대상을 노린다 (Monster가 is_engaged()를 본다)
## - 무리 중 아무도 직접 싸우지 않게 되면 다 같이 멈춘다
## 부모가 자식보다 먼저 처리되므로, 이번 프레임의 판단은 몬스터들의 지난 프레임 상태로 한다.

var _engaged: bool = false


func _physics_process(_delta: float) -> void:
	_engaged = false
	for monster: Monster in get_members():
		if monster.is_engaged_by_itself():
			_engaged = true
			return


## 무리 전체가 싸우는 중인지
func is_engaged() -> bool:
	return _engaged


## 아직 살아 있는 무리 몬스터들
func get_members() -> Array[Monster]:
	var members: Array[Monster] = []
	for child: Node in get_children():
		var monster: Monster = child as Monster
		if monster != null and not monster.is_queued_for_deletion() and monster.health > 0.0:
			members.append(monster)
	return members
