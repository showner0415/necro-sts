class_name ItemIcon
extends TextureRect
## 칸에 보이는 아이템 그림 하나 (ui/item_icon.tscn). 인벤토리·창고·상자 칸(InventorySlot), 핫바 칸(HotbarSlot), 수리 칸(RepairSlot)과
## 끄는 동안 마우스를 따라다니는 그림(InventorySlot.make_drag_preview)이 같이 쓴다.
## - 아이템 데이터에 icon이 있으면 그 그림을 icon_size로 그린다. 그림은 UI 기준 해상도(1920×1080) 기준 144×144라 줄여 그리므로,
##   장면에서 이 노드만 선형 필터 + 밉맵으로 둔다 (프로젝트 기본은 도트용 nearest). 아이콘 파일은 임포트에서 밉맵을 켠다
##   (assets/ASSETS.md의 아이템 아이콘 줄. 끄면 밉맵 없는 선형으로 그려져 1280×720에서 윤곽이 계단진다)
## - icon이 비면 그림 대신 임시 도형(placeholder_color·placeholder_size의 사각형)을 그린다 (바닥에 그리는 것과 같은 크기)
## - 아이템이 없으면(null) 숨는다. 시나리오가 칸의 %Icon.visible로 "칸에 아이템이 보이는지"를 본다
## 크기는 custom_minimum_size로 알리고, 칸 가운데에 두는 것은 바깥(칸 장면의 CenterContainer)이 한다.
## 클릭은 받지 않는다 (장면에서 mouse_filter IGNORE. 끌어서 놓기는 칸이 받는다).

## 아이콘 그림을 그릴 크기 (UI 좌표, 640×360 기준. 칸 32 가운데 24 → 1280×720에서 48px, 1920×1080에서 72px)
@export var icon_size: Vector2 = Vector2(24, 24)

var _placeholder_color: Color = Color.WHITE


## 보여줄 아이템. null이면 숨긴다.
func show_item(item: ItemData) -> void:
	visible = item != null
	texture = item.icon if item != null else null
	if item != null:
		if item.icon != null:
			custom_minimum_size = icon_size
		else:
			_placeholder_color = item.placeholder_color
			custom_minimum_size = item.placeholder_size
	queue_redraw()


func _draw() -> void:
	# 그림이 있으면 TextureRect가 그린다. 없으면 임시 도형을 칸 크기만큼 칠한다.
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, size), _placeholder_color)
