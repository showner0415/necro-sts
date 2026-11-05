class_name CombatStats
extends RefCounted
## 행동 조각(MonsterBehavior)이 쓰는 능력치 묶음.
## 같은 조각을 적과 언데드가 같이 쓰므로, 수치는 쓰는 쪽이 자기 값(MonsterData의 적 값 / 언데드 값)으로 넣어 준다.

## 대상을 쫓을 때의 속도 (픽셀/초)
var move_speed: float
## 대상이 이 거리 안이면 멈춰서 공격한다 (픽셀)
var attack_range: float
## 몸으로 부딪혀 주는 피해
var contact_damage: float
## 공격 사이의 간격 (초)
var attack_cooldown: float


static func create(speed: float, attack_distance: float, damage: float, cooldown: float) -> CombatStats:
	var stats: CombatStats = CombatStats.new()
	stats.move_speed = speed
	stats.attack_range = attack_distance
	stats.contact_damage = damage
	stats.attack_cooldown = cooldown
	return stats
