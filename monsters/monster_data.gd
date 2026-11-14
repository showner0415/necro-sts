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
## 싸우는 동안 다른 몬스터와 떨어지려는 거리 (픽셀). 0이면 비켜 서지 않는다
@export var combat_spacing: float = 0.0
@export_group("던지기")
## 한 번에 연달아 던지는 돌 수
@export var throw_burst_count: int = 1
## 연달아 던질 때 돌 사이 간격 (초)
@export var throw_burst_interval: float = 0.25
## 돌마다의 예측 비율 (0이면 지금 자리를 노림, 1이면 도착할 곳을 정확히 노림). 돌 수보다 짧으면 마지막 값을 쓴다
@export var throw_lead_ratios: Array[float] = []
## 돌마다의 조준 오차 (±도). 돌 수보다 짧으면 마지막 값을 쓴다
@export var throw_aim_errors: Array[float] = []
@export_group("")
## 대상이 이 거리 안에 들어오면 쫓아온다
@export var detect_range: float = 80.0
## 대상이 이 거리 안이면 멈춰서 공격한다
@export var attack_range: float = 16.0
@export var contact_damage: float = 1.0
## 공격 사이의 간격 (초)
@export var attack_cooldown: float = 1.0

@export_group("추격")
## 종별 추격 포기 조건 (ChaseClock). 값이 0인 조건은 쓰지 않는다. 포기해도 돌아가지 않고 그 자리에서 평소 행동을 한다.
## 무리(MonsterPack)는 무리원 모두가 자기 조건을 넘어야 함께 포기한다.
## 쫓는 대상(감지 범위 밖에서 때린 공격자, 보다가 놓친 대상, 무리 대상)과 이 거리보다 멀어지면 포기한다 (픽셀)
@export var chase_attacker_limit: float = 350.0
## 쫓는 대상을 이 시간(초) 넘게 보지 못하면(벽 뒤로 숨음) 포기한다. 다시 보면 처음부터 잰다 (임시값)
@export var chase_lost_time: float = 5.0
## 감지 범위 밖의(또는 안 보이는) 대상을 이 시간(초) 넘게 쫓으면 포기한다. 감지 범위 안에서 보이거나 맞으면 처음부터 잰다 (임시값)
@export var chase_time_limit: float = 0.0

@export_group("무리")
## 무리(MonsterPack)에서 대상 하나를 함께 노린다 (박쥐). 한 마리라도 어그로가 끌리면 무리 전체가 그 대상을 노리고(PackAggro), 경보 신호를 쓰지 않는다.
## 무리의 첫 멤버 값으로 정한다. false면 무리 경보(PackAlarm)를 쓴다: 신호 뒤 경보, 무리원마다 가장 가까운 적을 고른다
@export var pack_one_target: bool = false
## 무리원이 맞거나 적을 감지했을 때, 멈춰 깜빡이며 무리에 알리는 시간 (초, 임시값). 끝나면 무리 전체가 경보 상태가 된다
@export var alarm_signal_time: float = 0.3
## 대상 하나를 동시에 공격할 수 있는 이 종의 수 (공격권, AttackTokens. 대상마다 모든 몬스터가 함께 센다). 0이면 공격권 없이 공격한다 (박쥐)
@export var attack_tokens_per_target: int = 0
## 공격권이 없을 때 대상 둘레를 맴돌며 기다리는 거리 (픽셀, 임시값)
@export var token_wait_distance: float = 64.0

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
## 언데드일 때의 시야 (거리·각도 등). 비어 있으면 기본값 (UNDEAD_SIGHT_DEFAULT_PATH)
@export var undead_sight: SightData

## 언데드 능력치는 몬스터 값에서 계산한다 (규칙: UndeadStatRules). 체력·공격력에만 배율, 나머지는 몬스터와 같다.
## 내구도가 가득 찼을 때의 값이다.
var undead_max_health: float:
	get:
		return max_health * get_undead_health_ratio()
var undead_contact_damage: float:
	get:
		return contact_damage * get_undead_damage_ratio()

const UNDEAD_STAT_RULES_PATH: String = "res://data/undead_stat_rules.tres"
const UNDEAD_SIGHT_DEFAULT_PATH: String = "res://data/sight/undead_default.tres"
static var _default_sight: SightData
static var _undead_rules: UndeadStatRules

@export_group("그림")
## 살아 있는 몬스터의 8방향 정지 그림 (Facing 순서: 동, 남동, 남, 남서, 서, 북서, 북, 북동). 8장이 아니면 임시 도형으로 그린다.
## 언데드와 시체는 그림이 있어도 임시 도형이다. 충돌 모양은 그림과 상관없이 임시 도형 값(아래)으로 정한다.
@export var direction_textures: Array[Texture2D] = []
## 그림의 기준점(발밑) offset. 모든 방향에 같은 값을 쓴다 (방향마다 다르면 방향이 바뀔 때 들썩여 보인다)
@export var sprite_offset: Vector2 = Vector2.ZERO

@export_group("임시 도형")
@export var placeholder_color: Color = Color.WHITE
## 원, 가로로 긴 타원 (네발짐승 등), 가로로 넓은 마름모 (날개 편 박쥐 등)
@export var placeholder_shape: PlaceholderShape = PlaceholderShape.CIRCLE
## 원일 때: 그림과 충돌 판정에 같이 쓰는 원의 반지름
@export var placeholder_radius: float = 5.0
## 타원·마름모일 때: 가로 반지름, 세로 반지름
@export var placeholder_ellipse_size: Vector2 = Vector2(10, 6)


## 살아 있는 몬스터를 그림으로 그리는지 (8방향 그림이 다 있을 때)
func has_sprite() -> bool:
	return direction_textures.size() == FacingSprite.DIRECTION_NAMES.size()


## 8방향 그림으로 정지 그림 애니메이션(idle_<방향>)만 든 SpriteFrames를 만든다 (FacingSprite용). 걷기 애니메이션은 없다.
func make_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for i: int in FacingSprite.DIRECTION_NAMES.size():
		var animation: StringName = StringName(FacingSprite.IDLE_PREFIX + FacingSprite.DIRECTION_NAMES[i])
		frames.add_animation(animation)
		frames.set_animation_loop(animation, false)
		frames.add_frame(animation, direction_textures[i])
	return frames


## 언데드일 때의 시야 (undead_sight가 비어 있으면 기본값). 기본값은 한 번 불러 붙잡아 둔다
## (아무도 붙잡지 않으면 캐시에서 내려가 부를 때마다 파일을 다시 읽는다)
func get_undead_sight() -> SightData:
	if undead_sight != null:
		return undead_sight
	if _default_sight == null:
		_default_sight = load(UNDEAD_SIGHT_DEFAULT_PATH)
	return _default_sight


## 적일 때 쓰는 행동 조각의 복사본 (한 마리에 하나)
func make_enemy_behavior() -> MonsterBehavior:
	return behavior.make_instance()


## 언데드일 때 쓰는 행동 조각의 복사본. undead_behavior가 비었으면 적일 때와 같은 조각.
func make_undead_behavior() -> MonsterBehavior:
	return (undead_behavior if undead_behavior != null else behavior).make_instance()


func get_enemy_stats() -> CombatStats:
	var stats: CombatStats = _with_throw_stats(CombatStats.create(move_speed, attack_range, contact_damage, attack_cooldown))
	stats.wait_distance = token_wait_distance
	return stats


func _with_throw_stats(stats: CombatStats) -> CombatStats:
	stats.burst_count = throw_burst_count
	stats.burst_interval = throw_burst_interval
	stats.lead_ratios = throw_lead_ratios
	stats.aim_errors = throw_aim_errors
	return stats


## 언데드일 때의 능력치: 이동 속도·공격 간격은 몬스터와 같고, 공격력만 배율을 곱한다. 공격 거리는 따로 둔 값이 없으면 몬스터와 같다.
## 네임드 머리뼈(named)면 공격력은 원래 몬스터 공격력에 네임드 배율을 곱한다 (계획 6b).
func get_undead_stats(named: bool = false) -> CombatStats:
	var damage: float = contact_damage * get_undead_rules().named_damage_ratio if named else undead_contact_damage
	return _with_throw_stats(CombatStats.create(move_speed, get_undead_attack_range(), damage, attack_cooldown))


## 언데드 공격 거리 (이 몬스터에 따로 둔 값이 있으면 그것, 없으면 몬스터의 attack_range)
func get_undead_attack_range() -> float:
	return undead_attack_range_override if undead_attack_range_override >= 0.0 else attack_range


## 언데드 체력 배율 (이 몬스터에 따로 둔 값이 있으면 그것, 없으면 기본 배율)
func get_undead_health_ratio() -> float:
	return undead_health_ratio_override if undead_health_ratio_override >= 0.0 else get_undead_rules().health_ratio


## 언데드 공격력 배율 (이 몬스터에 따로 둔 값이 있으면 그것, 없으면 기본 배율)
func get_undead_damage_ratio() -> float:
	return undead_damage_ratio_override if undead_damage_ratio_override >= 0.0 else get_undead_rules().damage_ratio


## 언데드 최대 체력. 네임드 머리뼈(named)면 원래 몬스터 체력에 네임드 배율을 곱한다 (몬스터별 배율은 쓰지 않는다, 계획 6b)
func get_undead_max_health(named: bool = false) -> float:
	return max_health * get_undead_rules().named_health_ratio if named else undead_max_health


## 드랍 목록의 첫 머리뼈 (없으면 null). 대장의 네임드 머리뼈가 이 종류로 나온다 (계획 6b)
func get_drop_skull() -> SkullData:
	for entry: DropEntry in drops:
		if entry != null and entry.item is SkullData:
			return entry.item as SkullData
	return null


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
