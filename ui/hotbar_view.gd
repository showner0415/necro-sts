class_name HotbarView
extends HBoxContainer
## 화면에 항상 보이는 핫바. Hotbar의 칸 수만큼 HotbarSlot을 만들어 보여준다.
## 칸에서 온 요청(놓기·자리 바꾸기·빼기)을 Hotbar에 그대로 전한다.
## 선택된 칸(Hotbar.selected_index)과 소환 중인 머리뼈(UndeadRoster)는 칸 테두리로 보여준다.

@export var slot_scene: PackedScene

var _hotbar: Hotbar
var _roster: UndeadRoster
var _slots: Array[HotbarSlot] = []


## 보여줄 핫바를 연결하고 칸을 만든다. roster가 있으면 소환 중 테두리도 보여준다.
func bind(hotbar: Hotbar, roster: UndeadRoster = null) -> void:
	_hotbar = hotbar
	_roster = roster
	_hotbar.changed.connect(_refresh)
	_hotbar.selection_changed.connect(func(_index: int) -> void: _refresh())
	if _roster != null:
		_roster.changed.connect(_refresh)
	for i: int in _hotbar.get_slot_count():
		var slot: HotbarSlot = slot_scene.instantiate()
		slot.index = i
		add_child(slot)
		slot.assign_requested.connect(func(index: int, skull: Skull) -> void: _hotbar.assign(index, skull))
		slot.swap_requested.connect(func(from_index: int, to_index: int) -> void: _hotbar.swap(from_index, to_index))
		slot.clear_requested.connect(func(index: int) -> void: _hotbar.clear_slot(index))
		_slots.append(slot)
	_refresh()


## 테스트·디버그용: 그 번호의 칸
func get_slot_control(index: int) -> HotbarSlot:
	return _slots[index]


func _refresh() -> void:
	for i: int in _slots.size():
		var skull: Skull = _hotbar.get_skull(i)
		_slots[i].show_skull(skull)
		var summoned: bool = _roster != null and skull != null and _roster.is_summoned(skull)
		_slots[i].show_state(i == _hotbar.selected_index, summoned)
