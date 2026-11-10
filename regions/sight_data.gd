class_name SightData
extends Resource
## 언데드 시야 값 (몬스터 데이터의 undead_sight가 가리킨다. 비어 있으면 기본값 data/sight/undead_default.tres).
## 모양은 플레이어 시야와 같다: 바라보는 방향에서 좌우 full_angle까지 밝고 total_angle까지 매끄럽게 어두워지는 부채꼴,
## 둘레 원(near_radius, 0이면 없음), 벽 뒤는 안 보인다. 지형은 이 언데드의 빛으로 brightness만큼 밝아진다.

@export var id: StringName = &""
## 보는 거리 (픽셀)
@export var view_range: float = 200.0
## 바라보는 방향에서 좌우 이 각도까지 완전히 밝다 (도)
@export var full_angle: float = 23.0
## 보이는 범위 전체: 좌우 이 각도 (도)
@export var total_angle: float = 35.0
## 방향과 상관없이 보이는 둘레 반지름 (픽셀, 0이면 둘레 원 없음)
@export var near_radius: float = 0.0
## 둘레 원 바깥으로 어두워지는 폭 (픽셀)
@export var near_fade: float = 8.0
## 이 빛만 받은 지형의 밝기 (원래 색 = 1)
@export var brightness: float = 0.75
## 바라보는 방향이 도는 가장 빠른 속도 (도/초)
@export var turn_speed: float = 360.0


## 이 시야의 판정 규칙 (벽은 따로 set_walls로 넣는다)
func make_rules() -> VisionRules:
	var rules: VisionRules = VisionRules.new()
	rules.full_angle = full_angle
	rules.total_angle = total_angle
	rules.near_radius = near_radius
	rules.view_range = view_range
	return rules
