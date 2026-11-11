class_name BodyLayer
extends Node3D
## 몸(네크로맨서, 몬스터, 언데드, 시체, 줍는 물건, 상자, 탄, 돌)을 2D 노드에서 읽어 3D 사각형으로 그린다. 규칙에는 아무것도 돌려주지 않는다.
## - 탄과 돌은 높이가 있다: 2D에서 위쪽으로 옮겨 둔 만큼 발밑 평면으로 되돌리고 그 높이에 그린다. 돌의 포물선은 실제 높이가 된다
## - 그림이 있으면 숨긴 2D 그림(FacingSprite)의 지금 프레임을 그대로 쓴다. 8방향·걷기 규칙을 다시 만들지 않는다
## - 그림이 없으면 임시 도형과 같은 모양의 흰 형판(PlaceholderArt)에 2D와 같은 색을 곱한다
## - 위치·보임·투명도(시야 Vision이 정한 값)·맞았을 때 번쩍임은 프레임마다 2D 노드에서 옮긴다
## - 몸은 화면 픽셀에 맞춰 놓는다 (꿈틀거리지 않게)

const BODY_SHADER: String = "res://view_3d/body.gdshader"
## 몸 사각형이 카메라 밖으로 잘못 잘리지 않게 두는 여유 (단위)
const CULL_MARGIN: float = 4.0

## 몸 그림의 깊이만 카메라 쪽으로 당기는 양 (단위). 발밑보다 아래로 그려지는 부분이 바닥에 가리지 않게 한다
@export var depth_bias: float = 0.3

var _view: RegionView3D
var _shader: Shader
## 2D 노드 → _Visual
var _visuals: Dictionary = {}
## 그림 텍스처마다 불투명 영역 (한 번만 계산한다)
var _used_rects: Dictionary = {}


## add_child 전에 부른다.
func setup(view: RegionView3D) -> void:
	_view = view
	_shader = load(BODY_SHADER)


## nodes 중 몸마다 사각형을 하나 두고 프레임마다 옮긴다. 사라진 것은 지운다.
func sync_bodies(nodes: Array[Node2D], delta: float) -> void:
	var alive: Dictionary = {}
	for node: Node2D in nodes:
		if node.is_queued_for_deletion() or not _is_body(node):
			continue
		alive[node] = true
		if not _visuals.has(node):
			_visuals[node] = _make_visual(node)
		_update_visual(node, _visuals[node], delta)
	for node: Variant in _visuals.keys():
		if not alive.has(node):
			(_visuals[node] as _Visual).quad.queue_free()
			_visuals.erase(node)


## 지금 그리는 몸들 (2D 노드)
func get_bodies() -> Array[Node2D]:
	var bodies: Array[Node2D] = []
	for node: Variant in _visuals.keys():
		bodies.append(node as Node2D)
	return bodies


## 몸 그림이 화면에서 차지하는 사각형 (불투명한 부분만)
func get_see_rect(node: Node2D) -> Rect2:
	var visual: _Visual = _visuals[node]
	var feet: Vector2 = _view.world_to_screen(node.global_position, 0.0).round()
	if not _used_rects.has(visual.texture):
		var image: Image = visual.texture.get_image()
		_used_rects[visual.texture] = image.get_used_rect() if image != null else Rect2i(Vector2i.ZERO, Vector2i(visual.texture.get_size()))
	var used: Rect2i = _used_rects[visual.texture]
	return Rect2(feet + visual.offset + Vector2(used.position), Vector2(used.size))


## 상자가 시야 안에 있는 정도 (0~1). 앞벽 처리가 쓴다.
func get_chest_sight(node: Node2D) -> float:
	return maxf((_visuals[node] as _Visual).sight, 0.0) if _visuals.has(node) else 0.0


## 확인용: 몸의 3D 사각형 (없으면 null)
func get_quad(node: Node2D) -> MeshInstance3D:
	return (_visuals[node] as _Visual).quad if _visuals.has(node) else null


func get_depth_bias() -> float:
	return depth_bias


func _is_body(node: Node2D) -> bool:
	return node is Necromancer or node is Monster or node is Undead or node is Corpse or node is Pickup or node is LootChest or node is StorageChest or node is RepairMachine or node is Bolt or node is Stone


func _make_visual(node: Node2D) -> _Visual:
	var visual: _Visual = _Visual.new()
	var quad: MeshInstance3D = MeshInstance3D.new()
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	quad.mesh = mesh
	visual.material = ShaderMaterial.new()
	visual.material.shader = _shader
	visual.material.set_shader_parameter(&"depth_bias", depth_bias)
	quad.material_override = visual.material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.extra_cull_margin = CULL_MARGIN
	add_child(quad)
	visual.quad = quad
	for child: Node in node.get_children():
		if child is FacingSprite:
			visual.sprite = child as FacingSprite
	return visual


func _update_visual(node: Node2D, visual: _Visual, delta: float) -> void:
	var tint: Color = _read_art(node, visual)
	if node is InteractZone:
		_update_chest_sight(node, visual, delta)
	var size: Vector2 = visual.texture.get_size()
	visual.material.set_shader_parameter(&"sprite_texture", visual.texture)
	visual.material.set_shader_parameter(&"sprite_size", size)
	# 2D offset은 왼쪽 위 기준(아래가 +y), 셰이더는 왼쪽 아래 기준(위가 +y)이다.
	visual.material.set_shader_parameter(&"sprite_offset", Vector2(visual.offset.x, -(size.y + visual.offset.y)))
	# Color로 넘기면 선형으로 바뀌어 들어가므로, 2D와 같은 sRGB 값을 Vector4로 넘긴다.
	# 상자는 지형처럼 시야로 어둡고 밝아진다. 몸은 2D 노드의 투명도·번쩍임을 따른다.
	var color: Color = tint * _chest_brightness(visual) if node is InteractZone else tint * node.modulate
	visual.material.set_shader_parameter(&"tint", Vector4(color.r, color.g, color.b, color.a))
	visual.quad.global_position = _view.snap_to_pixels(_position_3d(node))
	visual.quad.visible = node.visible


## 상자가 시야 안에 있는 정도를 fade_time에 걸쳐 옮긴다. 시야가 없거나 꺼져 있으면 언제나 보인다.
func _update_chest_sight(node: Node2D, visual: _Visual, delta: float) -> void:
	var vision: Vision = _view.get_vision()
	var target: float = 1.0 if vision == null or vision.is_visible_at(node.global_position) else 0.0
	if visual.sight < 0.0:
		visual.sight = target
	elif vision != null and vision.fade_time > 0.0:
		visual.sight = move_toward(visual.sight, target, delta / vision.fade_time)
	else:
		visual.sight = target


func _chest_brightness(visual: _Visual) -> Color:
	var vision: Vision = _view.get_vision()
	var dark: float = vision.darkness if vision != null and vision.active else 1.0
	var level: float = lerpf(dark, 1.0, maxf(visual.sight, 0.0))
	return Color(level, level, level, 1.0)


## 몸을 놓을 3D 위치. 탄·돌은 2D에서 높이만큼 위쪽 자리에 있으므로 되돌리고 그 높이에 놓는다.
func _position_3d(node: Node2D) -> Vector3:
	if node is Bolt:
		return ViewSpace.aim_to_3d(node.global_position, _view.get_aim_height())
	if node is Stone:
		var stone: Stone = node as Stone
		return ViewSpace.to_3d(stone.global_position + Vector2(0, stone.ground_offset), stone.get_view_height())
	return ViewSpace.to_3d(node.global_position, 0.0)


## 지금 그릴 텍스처와 기준점을 visual에 넣고, 곱할 색을 돌려준다.
func _read_art(node: Node2D, visual: _Visual) -> Color:
	var sprite: FacingSprite = visual.sprite
	if sprite != null:
		sprite.view_rotation = deg_to_rad(_view.yaw_degrees)
		visual.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		visual.offset = sprite.offset
		return Color.WHITE
	var art: PlaceholderArt
	var tint: Color = Color.WHITE
	if node is Bolt:
		art = PlaceholderArt.for_disc((node as Bolt).visual_radius)
		tint = (node as Bolt).placeholder_color
	elif node is Stone:
		art = PlaceholderArt.for_disc((node as Stone).placeholder_radius)
		tint = (node as Stone).placeholder_color
	elif node is LootChest:
		var chest: LootChest = node as LootChest
		art = PlaceholderArt.for_chest(chest.box_size, chest.lid_height, chest.box_color, chest.lid_color)
	elif node is StorageChest:
		var storage: StorageChest = node as StorageChest
		art = PlaceholderArt.for_chest(storage.box_size, storage.lid_height, storage.box_color, storage.lid_color)
	elif node is RepairMachine:
		var machine: RepairMachine = node as RepairMachine
		art = PlaceholderArt.for_chest(machine.box_size, machine.top_height, machine.box_color, machine.top_color)
	elif node is Pickup:
		var item: Resource = (node as Pickup).stack.item
		art = PlaceholderArt.for_box(item.get(&"placeholder_size"))
		tint = item.get(&"placeholder_color")
	elif node is Corpse:
		var corpse: Corpse = node as Corpse
		art = PlaceholderArt.for_body(corpse.data, corpse.flatten_ratio, true)
		tint = corpse.get_placeholder_tint()
	elif node is Undead:
		art = PlaceholderArt.for_body((node as Undead).data, 1.0, false)
		tint = (node as Undead).get_placeholder_tint()
	else:
		art = PlaceholderArt.for_body((node as Monster).data, 1.0, false)
		tint = (node as Monster).get_placeholder_tint()
	visual.texture = art.texture
	visual.offset = art.offset
	return tint


class _Visual:
	var quad: MeshInstance3D
	var material: ShaderMaterial
	var sprite: FacingSprite
	var texture: Texture2D
	var offset: Vector2 = Vector2.ZERO
	## 상자가 시야 안에 있는 정도 (처음에는 -1)
	var sight: float = -1.0
