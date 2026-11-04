class_name MonsterData
extends Resource
## 몬스터 한 종류의 정의. 새 몬스터는 이 리소스의 .tres를 추가하고 monster.tscn에 넣어서 만든다.

@export var id: StringName
@export var display_name: String

@export_group("능력치")
@export var max_health: float = 3.0
## 대상을 쫓을 때의 속도 (픽셀/초)
@export var move_speed: float = 40.0
## 대상이 이 거리 안에 들어오면 쫓아온다
@export var detect_range: float = 80.0
## 대상이 이 거리 안이면 멈춰서 공격한다
@export var attack_range: float = 16.0
@export var contact_damage: float = 1.0
## 공격 사이의 간격 (초)
@export var attack_cooldown: float = 1.0

@export_group("배회")
@export var wander_speed: float = 15.0
## 배회 방향을 다시 고르는 간격 (초)
@export var wander_interval: float = 2.0
## 방향을 고를 때 멈춰 있기로 할 확률 (0~1)
@export_range(0.0, 1.0) var wander_rest_chance: float = 0.5

@export_group("드랍")
## 죽을 때 줄마다 확률을 굴려 떨어뜨린다 (DropRoller)
@export var drops: Array[DropEntry] = []

@export_group("임시 도형")
@export var placeholder_color: Color = Color.WHITE
## 그림과 충돌 판정에 같이 쓰는 원의 반지름
@export var placeholder_radius: float = 5.0
