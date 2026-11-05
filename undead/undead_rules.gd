class_name UndeadRules
extends RefCounted
## 언데드 체력 회복에 드는 뼈 계산.
## 필요한 뼈 = 처음 소환 비용 × (모자란 체력 / 최대 체력), 소수점은 올림.
## 뼈가 모자라면 가진 만큼 일부 회복한다: 뼈 하나당 최대 체력 / 처음 소환 비용.

## 프레임마다 깎인 체력은 1.9999처럼 정수에 살짝 못 미칠 수 있다. 올림 전에 이 단위로 맞춘다.
const TOLERANCE: float = 0.0001


## 체력을 가득 채우는 데 드는 뼈 개수. 가득 차 있으면 0, 체력 0이면 처음 소환 비용과 같다.
static func heal_bone_cost(health: float, max_health: float, bone_cost: int) -> int:
	if max_health <= 0.0 or health >= max_health:
		return 0
	var missing_ratio: float = (max_health - maxf(health, 0.0)) / max_health
	return ceili(snappedf(bone_cost * missing_ratio, TOLERANCE))


## 뼈 하나로 회복하는 체력. 처음 소환 비용이 0이면 뼈 없이 가득 찬다(최대 체력).
static func health_per_bone(max_health: float, bone_cost: int) -> float:
	if bone_cost <= 0:
		return max_health
	return max_health / bone_cost


## bones개를 써서 회복한 뒤의 체력. 최대 체력을 넘지 않는다.
## 필요한 만큼 다 쓰면 정확히 최대 체력이 된다 (올림 때문에 조금 넘치는 것을 버린다).
static func health_after_heal(health: float, max_health: float, bone_cost: int, bones: int) -> float:
	if bones >= heal_bone_cost(health, max_health, bone_cost):
		return max_health
	return minf(health + health_per_bone(max_health, bone_cost) * bones, max_health)
