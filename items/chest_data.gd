class_name ChestData
extends Resource
## 상자 하나의 정의: 이름, 칸 수, 칸마다 굴릴 내용물 목록.
## 칸마다 entries 중 하나를 가중치에 따라 고른다 (빈 칸 항목 포함). 지역에 들어올 때마다 새로 굴린다.

@export var id: StringName
@export var display_name: String = "상자"
@export var slot_count: int = 6
@export var entries: Array[ChestLootEntry] = []
## 빈 칸이 드러나기까지 걸리는 희귀도 (빈 칸도 확인 전에는 무엇인지 모른다)
@export var empty_rarity: RarityData
## true면 내용물이 임시다 (설계에서 내용물이 아직 미정이라 뼈·머리뼈를 임시로 넣었다)
@export var placeholder_contents: bool = false
@export_multiline var note: String = ""
