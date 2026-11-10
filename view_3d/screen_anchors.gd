class_name ScreenAnchors
extends CanvasLayer
## 몸 곁에 화면 픽셀 그대로 띄우는 것들(스태미나 도넛, 키 안내 글자). 숨긴 2D 세계에서 이 층으로 옮겨 와, 프레임마다 3D 화면에서 몸이 있는 자리에 놓는다.
## 자기를 다루는 코드(도넛의 채움, 안내의 보임)는 그대로 돈다. 주인이 사라지면 같이 지운다.
## 몸과의 간격은 2D와 같은 화면 픽셀이다. 주인이 시야 밖에서 안 보이면 같이 안 보인다.

const PROMPT_PATH: String = "%Prompt"

var _view: RegionView3D
## _Anchor 목록
var _anchors: Array[_Anchor] = []
## 안내 글자를 이미 옮긴 주인
var _adopted: Dictionary = {}


## add_child 전에 부른다.
func setup(view: RegionView3D) -> void:
	_view = view
	# 3D 화면 위, HUD 아래에 그린다.
	layer = -1


## node를 이 층으로 옮겨 anchor_owner 곁에 붙인다. add_child 뒤에 부른다.
func adopt(item: CanvasItem, anchor_owner: Node2D) -> void:
	var anchor: _Anchor = _Anchor.new()
	anchor.item = item
	anchor.source = anchor_owner
	anchor.local_position = item.get(&"position")
	item.reparent(self, false)
	anchor_owner.tree_exiting.connect(_drop.bind(anchor))
	_anchors.append(anchor)


## nodes 중 안내 글자가 있는 새 노드를 옮기고, 모두 제자리에 놓는다.
func sync_anchors(nodes: Array[Node2D]) -> void:
	for node: Node2D in nodes:
		if _adopted.has(node) or node.is_queued_for_deletion() or not (node is GroundTarget or node is InteractZone):
			continue
		_adopted[node] = true
		var prompt: CanvasItem = node.get_node_or_null(PROMPT_PATH) as CanvasItem
		if prompt != null:
			adopt(prompt, node)
	for anchor: _Anchor in _anchors:
		anchor.item.set(&"position", _view.world_to_screen(anchor.source.global_position, 0.0).round() + anchor.local_position)
		anchor.item.modulate.a = anchor.source.modulate.a if anchor.source.visible else 0.0


func _drop(anchor: _Anchor) -> void:
	_anchors.erase(anchor)
	anchor.item.queue_free()


class _Anchor:
	var item: CanvasItem
	var source: Node2D
	var local_position: Vector2
