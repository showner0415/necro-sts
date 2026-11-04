class_name Hud
extends CanvasLayer
## 화면 왼쪽 위에 체력 바, 뼈 개수, 머리뼈 종류별 개수를,
## 왼쪽 아래에 핫바와 그 바로 아래 마나 바를 보여준다.
## 값은 바깥에서 show_* 함수로 넣어 주고, 핫바는 hotbar_view.bind()로 연결한다.

## 개수를 보여줄 아이템
@export var bone_item: ItemData

@onready var hotbar_view: HotbarView = %HotbarView
@onready var _health_bar: StatBar = %HealthBar
@onready var _mana_bar: StatBar = %ManaBar
@onready var _bone_label: Label = %BoneLabel
@onready var _skull_list: VBoxContainer = %SkullList


func show_health(current: float, maximum: float) -> void:
	_health_bar.set_values(current, maximum)


func show_mana(current: float, maximum: float) -> void:
	_mana_bar.set_values(current, maximum)


func show_item_count(item_id: StringName, count: int) -> void:
	if item_id == bone_item.id:
		_bone_label.text = "%s %d" % [bone_item.display_name, count]


## 머리뼈 종류마다 "쥐의 머리뼈 2"처럼 한 줄씩 보여준다. 가진 것이 없으면 아무 줄도 없다.
func show_skull_counts(counts: Dictionary[SkullData, int]) -> void:
	for child: Node in _skull_list.get_children():
		_skull_list.remove_child(child)
		child.queue_free()
	for skull_data: SkullData in counts:
		var label: Label = Label.new()
		label.text = "%s %d" % [skull_data.display_name, counts[skull_data]]
		_skull_list.add_child(label)


## 테스트·디버그용: 지금 보이는 머리뼈 줄들의 글자
func get_skull_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for child: Node in _skull_list.get_children():
		lines.append((child as Label).text)
	return lines
