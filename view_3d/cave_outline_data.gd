class_name CaveOutlineData
extends Resource
## 맵 PNG에서 만든 동굴 벽 윤곽 (tools/map_png/make_cave_outline.gd가 만든다). 격자 점은 칸 모서리와 맞는다: 칸마다 per_cell칸.

const FIELD_LOW: float = 0.25
const FIELD_HIGH: float = 0.75

@export var settings: CaveOutlineSettings
## 맵 크기 (칸)와 칸 크기 (픽셀)
@export var cell_count: Vector2i
@export var cell_px: int = 32
## 격자 점의 값 (가로 nodes().x개씩 줄 순서). FIELD_LOW~FIELD_HIGH를 0~255로 담는다
@export var values: PackedByteArray
## 칸마다 0 = 바닥뿐, 1 = 윤곽이 지남, 2 = 바위뿐
@export var cell_states: PackedByteArray
## 닫힌 윤곽선들 (단순화함, 월드 픽셀. 규칙용으로 B단계에서 쓴다)
@export var loops: Array[PackedVector2Array]


## 한 칸을 나누는 수
func per_cell() -> int:
	return cell_px / settings.sample_px


## 격자 점 수
func nodes() -> Vector2i:
	return cell_count * per_cell() + Vector2i.ONE


static func encode(value: float) -> int:
	return clampi(roundi((value - FIELD_LOW) / (FIELD_HIGH - FIELD_LOW) * 255.0), 0, 255)


static func decode(byte: int) -> float:
	return FIELD_LOW + byte / 255.0 * (FIELD_HIGH - FIELD_LOW)


## 벽이 기울어 들어가는 1픽셀이 값으로 얼마인지: 흐린 경계의 기울기 1 / (σ√(2π))
func field_per_px() -> float:
	return 1.0 / (settings.blur_sigma_px * sqrt(TAU))
