class_name CaveOutlineSettings
extends Resource
## 동굴 벽 윤곽을 만드는 값 (CaveOutline)과 그 윤곽으로 벽을 세우는 값 (CaveTerrainMesher). 모두 제안 값이다 (docs/plans/2026-11-10_cave_terrain_plan.md).

@export_group("윤곽")
## 표본 간격 (픽셀). 칸 크기를 나누어떨어지게 둔다
@export var sample_px: int = 4
## 가우스 흐리기의 표준편차 (픽셀)
@export var blur_sigma_px: float = 22.0
## 이 값 이상이면 바위다
@export var threshold: float = 0.5
@export var noise_seed: int = 1
## 큰 노이즈·작은 노이즈의 크기 (픽셀)와 세기
@export var large_noise_px: float = 40.0
@export var large_noise_strength: float = 0.10
@export var small_noise_px: float = 14.0
@export var small_noise_strength: float = 0.04
## PNG에서 3칸보다 좁은 바닥과 그 둘레 2칸 안에서는, PNG의 벽에서 이 거리 넘게 떨어진 바닥을 바위로 만들지 않는다 (픽셀)
@export var narrow_width_cells: int = 3
@export var protect_ring_cells: int = 2
@export var protect_guard_px: float = 6.0
## 좁은 길목 보호 구역에서는 값을 이만큼 빼서 바위를 조금 물린다 (PNG에서 어긋나게 이어진 2칸 길목은 흐리기만으로 좁아진다)
@export var protect_field_bias: float = 0.05
## 이 크기(한 변, 픽셀)보다 작은 바위 부스러기와 구멍을 없앤다
@export var min_piece_px: float = 48.0
## 윤곽선 단순화 오차 (픽셀). 메시와 규칙이 이 윤곽선을 쓴다
@export var simplify_px: float = 1.5
## 시야 판정에 쓰는 작은 칸 한 변 (픽셀). 표본 간격의 배수로, 칸 크기를 나누어떨어지게 둔다
@export var sight_cell_px: int = 8

@export_group("벽 메시")
## 벽이 위로 갈수록 바위 쪽으로 들어가는 최대 거리 (픽셀)와 그 무늬의 크기 (픽셀)
@export var max_lean_px: float = 6.0
@export var lean_noise_px: float = 24.0
## 맨 아래 이 높이까지는 윤곽에 붙인다 (픽셀)
@export var foot_height_px: float = 6.0
## 벽 면을 나누는 높이들 (픽셀, 맨 아래·맨 위 제외. foot_height_px 위)
@export var face_rows_px: PackedFloat32Array = PackedFloat32Array([67.0])
