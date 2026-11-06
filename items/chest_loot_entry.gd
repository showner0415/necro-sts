class_name ChestLootEntry
extends Resource
## 상자 칸 하나에 들어갈 수 있는 것 하나와 그 가중치. 칸마다 상자 데이터의 항목 중 하나를 가중치에 따라 고른다.
## item이 비어 있으면 빈 칸이다. 머리뼈(SkullData)면 count와 상관없이 머리뼈 하나다.

## 들어갈 아이템 (비우면 빈 칸)
@export var item: ItemData
## 개수 범위 (머리뼈가 아닐 때)
@export var min_count: int = 1
@export var max_count: int = 1
## 고를 가중치 (다른 항목과의 비율)
@export var weight: float = 1.0
