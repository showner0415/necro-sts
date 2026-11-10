class_name GroundMarks
extends Node3D
## 바닥에 그리는 표시(돌진 방향 선, 돌 그림자 원, 탈출 지점, 출구)를 3D 바닥에 입힌다.
## - 표시를 가진 2D 노드(draw_ground_marks가 있는 노드)의 그리기 코드를 그대로 쓴다. 카메라를 따라가는 2D 캔버스(SubViewport)에 월드 좌표로 그리고, 그 그림을 바닥 높이의 판에 입힌다
## - 판은 벽에 가리고, 몸은 판 위에 그려진다
## - 2D 선 두께가 1픽셀이어도 비스듬한 바닥에서 끊기지 않게, 월드 1픽셀을 캔버스 texels_per_pixel픽셀로 그린다

const SHADER_PATH: String = "res://view_3d/ground_marks.gdshader"

## 캔버스가 덮는 월드 크기 (픽셀, 한 변). 화면 대각선과 앞서 가기를 덮는다
@export var world_size: int = 1280
## 월드 1픽셀을 캔버스 몇 픽셀로 그릴지
@export var texels_per_pixel: int = 2
## 판의 높이 (픽셀). 바닥과 깊이가 겹치지 않을 만큼만 띄운다
@export var floor_height_px: float = 0.25

var _canvas: SubViewport
var _quad: MeshInstance3D
## 2D 노드 → _Mark
var _marks: Dictionary = {}


func _ready() -> void:
	_canvas = SubViewport.new()
	_canvas.size = Vector2i(world_size, world_size) * texels_per_pixel
	_canvas.transparent_bg = true
	_canvas.disable_3d = true
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_canvas)
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2.ONE * (world_size / ViewSpace.TILE)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter(&"marks", _canvas.get_texture())
	_quad = MeshInstance3D.new()
	_quad.mesh = mesh
	_quad.material_override = material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)


## nodes 중 표시가 있는 노드를 캔버스에 옮긴다. center: 캔버스 가운데 (월드 좌표, 화면 가운데가 보는 바닥)
func sync_marks(nodes: Array[Node2D], center: Vector2) -> void:
	var alive: Dictionary = {}
	for node: Node2D in nodes:
		if node.is_queued_for_deletion() or not node.has_method(&"draw_ground_marks"):
			continue
		alive[node] = true
		if not _marks.has(node):
			var mark: _Mark = _Mark.new()
			mark.source = node
			_canvas.add_child(mark)
			_marks[node] = mark
		var mark: _Mark = _marks[node]
		mark.global_position = node.global_position
		mark.modulate = node.modulate
		mark.visible = node.visible
		mark.queue_redraw()
	for node: Variant in _marks.keys():
		if not alive.has(node):
			(_marks[node] as _Mark).queue_free()
			_marks.erase(node)
	# 판과 캔버스를 월드 정수 픽셀에 맞춘다 (표시가 꿈틀거리지 않게).
	var snapped_center: Vector2 = center.round()
	var scale_factor: float = float(texels_per_pixel)
	_canvas.canvas_transform = Transform2D(0.0, Vector2.ONE * scale_factor, 0.0, -snapped_center * scale_factor + Vector2(_canvas.size) * 0.5)
	_quad.global_position = ViewSpace.to_3d(snapped_center, floor_height_px)


## 표시 하나를 대신 그리는 노드. 위치가 월드 좌표라 돌진 선 길이 계산(벽까지)도 그대로 맞는다.
class _Mark:
	extends Node2D

	var source: Node2D

	func _draw() -> void:
		source.call(&"draw_ground_marks", self)
