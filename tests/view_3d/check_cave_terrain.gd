extends ScenarioTest
## 새 동굴 지형(CaveTerrainMesher) 검사. 창 없이 메시를 직접 만들어 본다. run_all.sh에는 넣지 않는다.
## - 구역 경계: 이웃한 두 구역이 경계선에서 윗면을 같은 길이만큼 덮는지 (한쪽만 덮으면 틈이다)
## - 삼각형 수, 만드는 시간, 벽의 가장 큰 기울기
## 실행: bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/view_3d/check_cave_terrain.gd

const SCENE: String = "res://regions/shallow_cave.tscn"
const CHUNK_CELLS: int = 16
const SEAM_TOLERANCE: float = 0.05


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	var walls: PlaceholderWalls = current_scene.get_node("Walls")
	var view: RegionView3D = RegionView3D.new()
	var height: float = view.wall_height_px
	var cap: float = view.cut_cap_height_px
	view.free()
	var started: int = Time.get_ticks_msec()
	var old: Array[ArrayMesh] = TerrainMesher.new().build(TerrainCells.from_walls(walls), CHUNK_CELLS, height, cap)
	var old_ms: int = Time.get_ticks_msec() - started
	var meshes: Array[ArrayMesh] = CaveTerrainMesher.build_for(walls, SCENE, CHUNK_CELLS, height, cap, [])
	if meshes.is_empty():
		fail_step("메시", "윤곽 파일이 없음")
		return
	pass_step("메시", "구역 %d, 삼각형 %d, 만드는 시간 %dms (칸 지형 %dms, 구역 %d), 벽의 가장 큰 기울기 %.1fpx" % [meshes.size(), CaveTerrainMesher.last_triangles, CaveTerrainMesher.last_usec / 1000, old_ms, old.size(), CaveTerrainMesher.last_max_lean])
	var unit: float = float(walls.tile_size) * CHUNK_CELLS / ViewSpace.TILE
	var seams: Dictionary = {}
	for mesh: ArrayMesh in meshes:
		_collect(mesh, unit, height / ViewSpace.TILE, seams)
	var compared: int = 0
	var worst: float = 0.0
	var worst_seam: Variant = null
	for key: Variant in seams.keys():
		# 맵 바깥쪽 가장자리에는 맞은편 구역이 없다.
		if key.y == 0 or key.y == ceili(float(walls.grid_size()[key.x]) / CHUNK_CELLS):
			continue
		var sides: Array = seams[key]
		var difference: float = absf(sides[0] - sides[1])
		compared += 1
		if difference > worst:
			worst = difference
			worst_seam = key
	if worst > SEAM_TOLERANCE:
		fail_step("구역 경계", "경계 %d개 중 가장 큰 차이 %.3f칸 (경계 %s, 허용 %.2f)" % [compared, worst, worst_seam, SEAM_TOLERANCE])
		return
	pass_step("구역 경계", "경계 %d개: 양쪽 구역이 덮는 윗면 길이의 가장 큰 차이 %.4f칸" % [compared, worst])
	finish(true)


## 이 메시에서 구역 경계선 위에 놓인 윗면 변의 길이를 쪽별로 더한다. 열쇠: [축, 경계 번호, 다른 축의 구역 번호]
func _collect(mesh: ArrayMesh, unit: float, top: float, seams: Dictionary) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var box: AABB = mesh.get_aabb()
	var center: Vector3 = box.position + box.size * 0.5
	var chunk: Vector2i = Vector2i(floori(center.x / unit), floori(center.z / unit))
	for corner: int in range(0, indices.size(), 3):
		for side: int in 3:
			var a: Vector3 = vertices[indices[corner + side]]
			var b: Vector3 = vertices[indices[corner + (side + 1) % 3]]
			if absf(a.y - top) > 0.001 or absf(b.y - top) > 0.001:
				continue
			_add_seam(seams, 0, a.x, b.x, a.z, b.z, chunk.x, chunk.y, unit)
			_add_seam(seams, 1, a.z, b.z, a.x, b.x, chunk.y, chunk.x, unit)


func _add_seam(seams: Dictionary, axis: int, a: float, b: float, along_a: float, along_b: float, own: int, other: int, unit: float) -> void:
	for side: int in 2:
		var line: float = (own + side) * unit
		if absf(a - line) < 0.0001 and absf(b - line) < 0.0001:
			var key: Vector3i = Vector3i(axis, own + side, other)
			if not seams.has(key):
				seams[key] = [0.0, 0.0]
			seams[key][side] += absf(along_a - along_b)
