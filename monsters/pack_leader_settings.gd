class_name PackLeaderSettings
extends Resource
## 무리 대장 값 (계획 6a·6b, docs/game-design.md "몬스터 무리"의 대장 줄. 이름 말고는 모두 임시값). 무리 자리(PackSpawn)가 읽고, 대장 몬스터가 죽을 때 네임드 머리뼈 값을 읽는다.

## 무리를 만들 때 대장이 생길 확률 (0~1)
@export_range(0.0, 1.0) var chance: float = 0.15
## 대장이 살아 있는 동안 같은 무리원(대장 포함)의 공격력 배율
@export var member_damage_ratio: float = 1.2
## 대장 자신의 체력 배율
@export var leader_health_ratio: float = 1.5
## 대장을 잡았을 때 네임드 머리뼈가 나올 확률 (0~1, 계획 6b. 나오면 그 시체의 일반 머리뼈 대신이다)
@export_range(0.0, 1.0) var named_skull_chance: float = 0.7
## 네임드 머리뼈의 고정 이름 ("쥐 그레카의 머리뼈", 사용자 결정 2026-11-14. 이름 생성 방식은 미정)
@export var named_skull_name: String = "그레카"
