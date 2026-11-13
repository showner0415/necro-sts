class_name CaveOutlineData
extends Resource
## 맵 PNG에서 만든 동굴 벽 윤곽 (tools/map_png/make_cave_outline.gd가 만든다). 격자 점은 칸 모서리와 맞는다: 칸마다 per_cell칸.

const FIELD_LOW: float = 0.25
const FIELD_HIGH: float = 0.75
## cell_states의 값
const CELL_FLOOR: int = 0
const CELL_MIXED: int = 1
const CELL_ROCK: int = 2

@export var settings: CaveOutlineSettings
## 맵 크기 (칸)와 칸 크기 (픽셀)
@export var cell_count: Vector2i
@export var cell_px: int = 32
## 격자 점의 값 (가로 nodes().x개씩 줄 순서). FIELD_LOW~FIELD_HIGH를 0~255로 담는다
@export var values: PackedByteArray
## 칸마다 0 = 바닥뿐, 1 = 윤곽이 지남, 2 = 바위뿐
@export var cell_states: PackedByteArray
## 닫힌 윤곽선들 (단순화함, 월드 픽셀). 화면의 벽과 규칙의 충돌이 같이 쓴다
@export var loops: Array[PackedVector2Array]
## 시야 판정용 작은 칸 (settings.sight_cell_px 크기, 가로 sight_size().x칸씩 줄 순서). 1 = 바위
@export var sight_cells: PackedByteArray
## 이 윤곽을 만든 맵 PNG의 md5 (PNG 없이 씬의 벽 배치로 만들었으면 빈 값)
@export var source_png_md5: String = ""


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


## 시야 판정용 작은 칸 수
func sight_size() -> Vector2i:
	return cell_count * cell_px / settings.sight_cell_px


## 이 자리(윤곽의 좌표, 픽셀)가 바위인지. 맵 밖은 바위다. 격자 점 사이는 이어서 본다.
func is_rock_at(point: Vector2) -> bool:
	var grid: Vector2 = point / settings.sample_px
	var size: Vector2i = nodes()
	if grid.x < 0.0 or grid.y < 0.0 or grid.x > size.x - 1 or grid.y > size.y - 1:
		return true
	var i: int = mini(floori(grid.x), size.x - 2)
	var k: int = mini(floori(grid.y), size.y - 2)
	var fx: float = grid.x - i
	var fy: float = grid.y - k
	var index: int = k * size.x + i
	var top: float = lerpf(values[index], values[index + 1], fx)
	var bottom: float = lerpf(values[index + size.x], values[index + size.x + 1], fx)
	return FIELD_LOW + lerpf(top, bottom, fy) / 255.0 * (FIELD_HIGH - FIELD_LOW) >= settings.threshold


## 가운데가 center이고 반 크기가 half인 사각형에 바위가 있는지. 사각형을 가장 가까운 격자 점으로 맞춰 그 안의 점을 본다 (길찾기가 칸마다 불러서 값을 바로 읽는다).
func box_has_rock(center: Vector2, half: Vector2) -> bool:
	var step: float = settings.sample_px
	var size: Vector2i = nodes()
	var i0: int = roundi((center.x - half.x) / step)
	var i1: int = roundi((center.x + half.x) / step)
	var k0: int = roundi((center.y - half.y) / step)
	var k1: int = roundi((center.y + half.y) / step)
	if i0 < 0 or k0 < 0 or i1 >= size.x or k1 >= size.y:
		return true
	var rock_byte: int = ceili((settings.threshold - FIELD_LOW) / (FIELD_HIGH - FIELD_LOW) * 255.0)
	var bytes: PackedByteArray = values
	for k: int in range(k0, k1 + 1):
		var line: int = k * size.x
		for i: int in range(i0, i1 + 1):
			if bytes[line + i] >= rock_byte:
				return true
	return false


## 벽이 기울어 들어가는 1픽셀이 값으로 얼마인지: 흐린 경계의 기울기 1 / (σ√(2π))
func field_per_px() -> float:
	return 1.0 / (settings.blur_sigma_px * sqrt(TAU))
