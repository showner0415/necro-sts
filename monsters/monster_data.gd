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
## 쫓는 대상(감지 범위 밖에서 때린 공격자, 또는 보다가 놓친 대상)과 이 거리보다 멀어지면 포기한다 (픽셀)
@export var chase_attacker_limit: float = 250.0
## 쫓는 대상이 보이는 동안, 쫓기 시작한 자리(맞기 시작한 자리 또는 처음 대상을 본 자리)에서 이 거리보다 멀어지면 포기하고 그 자리로 돌아간다 (픽셀, 임시값)
@export var chase_visible_home_limit: float = 400.0
## 쫓는 대상이 보이지 않게 된 뒤(벽 뒤로 숨음) 이 시간(초) 동안 다시 보지 못하면 포기한다. 다시 보면 처음부터 잰다 (임시값)
@export var chase_lost_time: float = 5.0
## 무리(MonsterPack)가 함께 포기하는 한계: 무리 싸움을 시작한 자리에서 이 거리보다 멀어진 멤버는 무리 대상을 더 원하지 않는다 (픽셀)
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
## 이 몬스터만 언데드 체력·공격력 배율을 따로 둘 때 (0보다 작으면 기본 배율, UndeadStatRules)
@export var undead_health_ratio_override: float = -1.0
@export var undead_damage_ratio_override: float = -1.0
## 이 몬스터만 언데드 공격 거리를 따로 둘 때 (0보다 작으면 몬스터의 attack_range와 같다).
## 쥐 언데드는 멧돼지 돌진에 맞는 범위(20) 밖에서 싸우도록 24로 둔다 (사용자 결정, 2026-11-08)
@export var undead_attack_range_override: float = -1.0
@export var undead_placeholder_color: Color = Color.WHITE

## 언데드 능력치는 몬스터 값에서 계산한다 (규칙: UndeadStatRules). 체력·공격력에만 배율, 나머지는 몬스터와 같다.
## 내구도가 가득 찼을 때의 값이다.
var undead_max_health: float:
	get:
		return max_health * get_undead_health_ratio()
var undead_contact_damage: float:
	get:
		return contact_damage * get_undead_damage_ratio()

const UNDEAD_STAT_RULES_PATH: String = "res://data/undead_stat_rules.tres"
static var _undead_rules: UndeadStatRules

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


## 언데드일 때의 능력치: 이동 속도·공격 간격은 몬스터와 같고, 공격력만 배율을 곱한다. 공격 거리는 따로 둔 값이 없으면 몬스터와 같다.
func get_undead_stats() -> CombatStats:
	return CombatStats.create(move_speed, get_undead_attack_range(), undead_contact_damage, attack_cooldown)


## 언데드 공격 거리 (이 몬스터에 따로 둔 값이 있으면 그것, 없으면 몬스터의 attack_range)
func get_undead_attack_range() -> float:
	return undead_attack_range_override if undead_attack_range_override >= 0.0 else attack_range


## 언데드 체력 배율 (이 몬스터에 따로 둔 값이 있으면 그것, 없으면 기본 배율)
func get_undead_health_ratio() -> float:
	return undead_health_ratio_override if undead_health_ratio_override >= 0.0 else get_undead_rules().health_ratio


## 언데드 공격력 배율 (이 몬스터에 따로 둔 값이 있으면 그것, 없으면 기본 배율)
func get_undead_damage_ratio() -> float:
	return undead_damage_ratio_override if undead_damage_ratio_override >= 0.0 else get_undead_rules().damage_ratio


## 언데드 능력치 기본 배율 (data/undead_stat_rules.tres, 처음 쓸 때 한 번 불러 둔다)
static func get_undead_rules() -> UndeadStatRules:
	if _undead_rules == null:
		_undead_rules = load(UNDEAD_STAT_RULES_PATH)
	return _undead_rules


## 임시 도형의 가로·세로 반지름 (원이면 둘 다 placeholder_radius)
func get_placeholder_half_size() -> Vector2:
	if placeholder_shape != PlaceholderShape.CIRCLE:
		return placeholder_ellipse_size
	return Vector2(placeholder_radius, placeholder_radius)
