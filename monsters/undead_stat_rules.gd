class_name UndeadStatRules
extends Resource
## 언데드 능력치 규칙의 기본 배율. 언데드는 원래 몬스터보다 약하다.
## - 배율은 체력과 공격력에만 적용한다. 이동 속도·공격 거리·공격 간격·행동의 타이밍(예고, 돌진 거리, 도는 반경 등)은 원래 몬스터와 같다
## - 이 배율은 머리뼈 내구도가 가득 찼을 때의 값이다. 내구도에 따른 감소는 그 위에 따로 적용한다 (설계 미정)
## - 몬스터마다 필요하면 MonsterData의 배율로 덮어쓴다
## - 네임드 언데드(네임드 머리뼈로 소환)는 named_* 배율을 쓴다. 원래 몬스터 값에 곱하고 몬스터별 배율은 쓰지 않는다 (계획 6b)

## 일반 언데드의 체력·공격력 배율 (임시값)
@export var health_ratio: float = 0.85
@export var damage_ratio: float = 0.85
## 네임드 언데드의 체력·공격력 배율 (임시값)
@export var named_health_ratio: float = 1.2
@export var named_damage_ratio: float = 1.2
