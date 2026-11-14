class_name PackLeaderSettings
extends Resource
## 무리 대장 값 (계획 6a, docs/game-design.md "몬스터 무리"의 대장 줄. 모두 임시값). 무리 자리(PackSpawn)가 읽는다.

## 무리를 만들 때 대장이 생길 확률 (0~1)
@export_range(0.0, 1.0) var chance: float = 0.15
## 대장이 살아 있는 동안 같은 무리원(대장 포함)의 공격력 배율
@export var member_damage_ratio: float = 1.2
## 대장 자신의 체력 배율
@export var leader_health_ratio: float = 1.5
