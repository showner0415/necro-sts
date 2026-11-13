class_name AttackData
extends Resource
## 네크로맨서 공격 한 종류의 정의. 업그레이드되면 피해량과 마나 비용이 같이 늘어난다 (docs/game-design.md 마나).

@export var id: StringName
@export var display_name: String
@export var damage: float = 1.0
## 한 번 쏠 때 쓰는 마나. 0이면 마나를 쓰지 않는다.
@export var mana_cost: float = 0.0
## 탄이 나간 뒤 다음 탄을 쏠 수 있을 때까지의 시간 (후딜레이, 초). 공격 버튼을 누르면 선딜레이 없이 바로 쏜다
@export var cooldown: float = 0.4
@export var projectile_speed: float = 200.0
## 탄이 사라지기 전까지 날아가는 거리
@export var projectile_range: float = 160.0
## 탄의 보이는 크기 (그리는 원의 반지름)
@export var projectile_visual_radius: float = 2.0
## 탄이 맞는 범위 (충돌 원의 반지름). 보이는 크기와 따로 조절한다.
@export var projectile_hit_radius: float = 2.0
