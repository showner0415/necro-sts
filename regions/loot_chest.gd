class_name LootChest
extends InteractZone
## 지역의 상자. 재료를 얻는 곳이다. 가까이(radius)에서 F를 누르면 interacted로 알리고, 지역 씬이 상자 화면을 연다.
## 내용물(ChestContents)은 이 노드가 지역에 들어올 때(씬이 만들어질 때) 데이터로 굴려 갖는다.
## 그래서 거점에 돌아갔다가 다시 나오면 새로 채워지고, 지역에 있는 동안은 닫았다 열어도 드러난 것이 그대로다.
## 열린 뒤에는 상자에서 open_distance 안에서 움직일 수 있고, 벗어나면 지역 씬이 닫는다.

@export var data: ChestData
## 열린 상자 창이 유지되는 거리 (상자 기준점에서 네크로맨서 발밑까지, 픽셀)
@export var open_distance: float = 48.0

@export_group("임시 도형")
## 상자 그림의 크기 (기준점은 바닥 가운데)
@export var box_size: Vector2 = Vector2(18, 12)
## 몸통·뚜껑 색 (Endesga 32의 733e39, c28569)
@export var box_color: Color = Color(0.4509804, 0.24313726, 0.22352941, 1)
@export var lid_color: Color = Color(0.7607843, 0.52156866, 0.4117647, 1)
@export var lid_height: float = 4.0

var contents: ChestContents


func _ready() -> void:
	super()
	if data != null:
		contents = ChestContents.roll(data)


func get_prompt_label() -> String:
	return data.display_name if data != null else "상자"


## 열린 상자 창을 유지할 수 있는 거리 안인지
func is_in_open_range(necromancer_position: Vector2) -> bool:
	return global_position.distance_to(necromancer_position) <= open_distance


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형: 상자와 뚜껑.
	draw_rect(Rect2(Vector2(-box_size.x / 2.0, -box_size.y), box_size), box_color)
	draw_rect(Rect2(Vector2(-box_size.x / 2.0, -box_size.y), Vector2(box_size.x, lid_height)), lid_color)
