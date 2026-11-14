class_name ChokeData
extends Resource
## 구운 길목 하나 (ChokeFinder가 만들고 CaveOutlineData.chokes에 담는다). 좌표는 맵 칸(cells)과 월드 픽셀(나머지).
## 길목에 들어가는 몬스터·돌아가는 몬스터·입구 밖에서 기다리는 몬스터는 이 값을 읽는다 (계획 4단계).

## 길목 칸 (맵 칸 좌표. 정수 값을 Vector2로 담는다)
@export var cells: PackedVector2Array = PackedVector2Array()
## 입구마다 가운데 (월드 픽셀). 입구는 길목 칸에 맞닿은 넓은 바닥 칸 덩어리다
@export var entrances: PackedVector2Array = PackedVector2Array()
## 입구마다 대기 자리 (월드 픽셀, entrances와 같은 순서)
@export var wait_spots: Array[PackedVector2Array] = []
## 입구 두 개마다(i < j 순서로 펼쳐서) 우회 비율 = 길목을 막은 길 ÷ 길목을 지나는 최단 길. 돌아갈 길이 없으면 -1
@export var detour_ratios: PackedFloat32Array = PackedFloat32Array()


## 입구 a와 b 사이의 우회 비율 (돌아갈 길이 없으면 -1)
func detour_ratio(a: int, b: int) -> float:
	if a == b:
		return 1.0
	var i: int = mini(a, b)
	var j: int = maxi(a, b)
	return detour_ratios[pair_index(i, j, entrances.size())]


## i < j인 입구 쌍이 detour_ratios에서 몇 번째인지
static func pair_index(i: int, j: int, count: int) -> int:
	return i * count - i * (i + 1) / 2 + (j - i - 1)
