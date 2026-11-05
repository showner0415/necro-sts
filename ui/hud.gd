class_name Hud
extends CanvasLayer
## 화면 왼쪽 위에 체력 바, 뼈 개수, 머리뼈 종류별 개수를,
## 왼쪽 아래에 핫바와 그 바로 아래 마나 바를, 아래 가운데에 탈출 게이지(탈출 지점 안에 있을 때만)를 보여준다.
## 값은 바깥에서 show_* 함수로 넣어 주고, 핫바는 hotbar_view.bind()로 연결한다.

## 개수를 보여줄 아이템
@export var bone_item: ItemData

@onready var hotbar_view: HotbarView = %HotbarView
@onready var _health_bar: StatBar = %HealthBar
@onready var _mana_bar: StatBar = %ManaBar
@onready var _bone_label: Label = %BoneLabel
@onready var _skull_list: VBoxContainer = %SkullList
@onready var _message_label: Label = %MessageLabel
@onready var _escape_gauge: Control = %EscapeGauge
@onready var _escape_bar: ProgressBar = %EscapeBar

## 안내 문구("뼈가 부족함" 등)가 떠 있는 시간 (초)
@export var message_duration: float = 2.0
var _message_time_left: float = 0.0


## 핫바 위에 안내 문구를 잠깐 띄운다. 장식용이라 클릭을 막지 않는다(mouse_filter IGNORE).
func show_message(text: String) -> void:
	_message_label.text = text
	_message_time_left = message_duration


## 화면 아래 가운데의 탈출 게이지. 0이면 숨기고, 0보다 크면 그 비율(0~1)만큼 채워 보여준다.
## 장식용이라 클릭을 막지 않는다(mouse_filter IGNORE).
func show_escape_progress(progress: float) -> void:
	_escape_gauge.visible = progress > 0.0
	_escape_bar.value = progress


## 테스트·디버그용: 탈출 게이지가 보이는지와 비율
func is_escape_gauge_visible() -> bool:
	return _escape_gauge.visible


func get_escape_progress() -> float:
	return _escape_bar.value


## 테스트·디버그용: 지금 떠 있는 안내 문구
func get_message() -> String:
	return _message_label.text


func _process(delta: float) -> void:
	if _message_time_left <= 0.0:
		return
	_message_time_left -= delta
	if _message_time_left <= 0.0:
		_message_label.text = ""


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
