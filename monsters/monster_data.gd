class_name MonsterData
extends Resource
## 몬스터 한 종류의 정의. 새 몬스터는 이 리소스의 .tres를 추가하고 monster.tscn에 넣어서 만든다.

## 임시 도형의 모양
enum PlaceholderShape { CIRCLE, ELLIPSE, DIAMOND }

@export var id: StringName
@export var display_name: String

@export_group("행동")
## 적일 때 대상과 싸우는 방식 (행동 조각)
@export var behavior: MonsterBehavior
## 언데드일 때 싸우는 방식. 비워 두면 적일 때와 같은 조각을 쓴다.
@export var undead_behavior: MonsterBehavior

## 날아다니는지. 날면 몸끼리 겹쳐 지나가고 벽에만 막힌다 (flying 충돌층).
@export var flying: bool = false

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

@export_group("추격")
## 감지 범위 밖에서 맞아 공격자를 쫓을 때, 공격자와 이 거리보다 멀어지면 포기한다 (픽셀)
@export var chase_attacker_limit: float = 250.0
## 감지 범위 밖에서 맞아 공격자를 쫓을 때, 맞기 시작한 자리에서 이 거리보다 멀어지면 포기하고 그 자리로 돌아간다 (픽셀)
@export var chase_home_limit: float = 150.0

@export_group("배회")
@export var wander_speed: float = 15.0
## 배회 방향을 다시 고르는 간격 (초)
@export var wander_interval: float = 2.0
## 방향을 고를 때 멈춰 있기로 할 확률 (0~1)
@export_range(0.0, 1.0) var wander_rest_chance: float = 0.5

@export_group("드랍")
## 죽을 때 줄마다 확률을 굴려, 나온 것을 시체에 담는다 (DropRoller)
@export var drops: Array[DropEntry] = []
## 시체에서 한 묶음을 채집하는 기본 시간 (초). 실제 시간은 여기에 아이템의 harvest_time_multiplier를 곱한다.
@export var harvest_base_time: float = 1.0

@export_group("언데드")
## 이 몬스터의 머리뼈로 처음 소환할 때 쓰는 뼈 개수. 체력 회복에 드는 뼈도 이 값에서 계산한다.
@export var summon_bone_cost: int = 4
## 소환할 때마다 쓰는 마나
@export var summon_mana_cost: float = 3.0
## 소환 중인 이 언데드 한 마리가 초당 쓰는 마나 (유지비)
@export var undead_upkeep_mana_per_second: float = 0.5
## 언데드가 죽은 판정이 되면 머리뼈 내구도가 이만큼 준다
@export var undead_death_durability_loss: float = 3.0
@export var undead_max_health: float = 4.0
@export var undead_move_speed: float = 60.0
## 언데드가 이 거리 안의 몬스터를 노린다
@export var undead_detect_range: float = 90.0
@export var undead_attack_range: float = 14.0
@export var undead_contact_damage: float = 1.0
@export var undead_attack_cooldown: float = 0.8
@export var undead_placeholder_color: Color = Color.WHITE

@export_group("임시 도형")
@export var placeholder_color: Color = Color.WHITE
## 원, 가로로 긴 타원 (네발짐승 등), 가로로 넓은 마름모 (날개 편 박쥐 등)
@export var placeholder_shape: PlaceholderShape = PlaceholderShape.CIRCLE
## 원일 때: 그림과 충돌 판정에 같이 쓰는 원의 반지름
@export var placeholder_radius: float = 5.0
## 타원·마름모일 때: 가로 반지름, 세로 반지름
@export var placeholder_ellipse_size: Vector2 = Vector2(10, 6)


## 적일 때 쓰는 행동 조각의 복사본 (한 마리에 하나)
func make_enemy_behavior() -> MonsterBehavior:
	return behavior.make_instance()


## 언데드일 때 쓰는 행동 조각의 복사본. undead_behavior가 비었으면 적일 때와 같은 조각.
func make_undead_behavior() -> MonsterBehavior:
	return (undead_behavior if undead_behavior != null else behavior).make_instance()


func get_enemy_stats() -> CombatStats:
	return CombatStats.create(move_speed, attack_range, contact_damage, attack_cooldown)


func get_undead_stats() -> CombatStats:
	return CombatStats.create(undead_move_speed, undead_attack_range, undead_contact_damage, undead_attack_cooldown)


## 임시 도형의 가로·세로 반지름 (원이면 둘 다 placeholder_radius)
func get_placeholder_half_size() -> Vector2:
	if placeholder_shape != PlaceholderShape.CIRCLE:
		return placeholder_ellipse_size
	return Vector2(placeholder_radius, placeholder_radius)
