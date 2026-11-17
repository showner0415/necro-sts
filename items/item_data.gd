class_name ItemData
extends Resource
## 줍거나 보유할 수 있는 아이템 한 종류의 정의 (뼈, 머리뼈, 조합 재료 등).

@export var id: StringName
@export var display_name: String
## 인벤토리 칸 우클릭 메뉴에 나오는 항목 (위에서부터 순서대로)
@export var actions: Array[ItemAction] = []
## 시체에서 채집할 때 몬스터의 기본 채집 시간에 곱하는 배율. 머리뼈는 항상 다른 아이템보다 크게 둔다.
@export var harvest_time_multiplier: float = 1.0
## 희귀도. 지금은 상자에서 무엇인지 드러나는 시간에만 쓴다. 비우면 흔함과 같이 본다 (ChestContents).
@export var rarity: RarityData
## 칸(인벤토리·창고·상자, 핫바, 수리)과 끄는 그림에 보이는 아이콘 (고해상도 UI 그림, assets/ui_hd/).
## 비면 칸에도 아래 임시 도형을 그린다. 바닥에 놓인 물건은 이 그림을 쓰지 않는다.
@export var icon: Texture2D

@export_group("임시 도형")
## 그림이 생기기 전까지 바닥에 그릴 사각형의 색과 크기. icon이 비면 칸에도 이것을 그린다.
@export var placeholder_color: Color = Color.WHITE
@export var placeholder_size: Vector2 = Vector2(6, 3)
