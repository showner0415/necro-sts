class_name PackData
extends Resource
## 무리 종류 하나 (계획 5b). 맵 PNG의 무리 색 하나가 이 데이터 하나를 가리키고, 지역의 무리 자리(PackSpawn)가 이것으로 무리를 만든다.
## 구성은 종마다 (몬스터 데이터, 최소, 최대) 목록이고, 수는 던전 시드 난수로 정한다 (사용자 결정 2026-11-14). 크기 값은 설계 문서의 임시값을 따른다.

@export var id: StringName
@export var display_name: String
@export var members: Array[PackMember] = []


## 이번에 만들 무리원들의 몬스터 데이터 (목록 순서대로, 종마다 rng로 고른 수만큼)
func roll(rng: RandomNumberGenerator) -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for member: PackMember in members:
		var count: int = rng.randi_range(member.min_count, maxi(member.min_count, member.max_count))
		for i: int in count:
			result.append(member.monster)
	return result
