class_name RarityData
extends Resource
## 아이템 희귀도 한 단계 (흔함·고급·희귀·전설). 지금은 상자에서 아이템이 드러나는 데 걸리는 시간에만 쓴다.

@export var id: StringName
@export var display_name: String
## 상자에서 이 희귀도의 아이템이 무엇인지 드러나기까지 걸리는 시간 (초)
@export var reveal_time: float = 1.0
