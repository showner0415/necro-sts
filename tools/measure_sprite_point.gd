extends SceneTree
## 방향별 그림에서 정한 색의 픽셀이 이어진 가장 큰 덩어리의 가운데를 잰다 (예: 네크로맨서 지팡이 보석 = 탄이 나가는 자리).
## 결과는 기준점에서의 오프셋(정수로 반올림)이다. 마지막 줄의 direction_muzzles는 예전에 탄 자리를 그림의 지팡이 보석으로 둘 때 쓰던 형식이다 (지금 탄은 몸 가운데에서 나간다, 2026-11-08).
## 덩어리가 없는 방향(그림에서 가려짐)은 "없음"으로 출력하므로 직접 정한다.
##
## bash tools/godot.sh --headless --path . -s tools/measure_sprite_point.gd -- --prefix=res://assets/necromancer/necromancer_ --colors=2ce8f5,0099db --origin=16,28
##
## --prefix: 그림 경로 앞부분. 뒤에 방향 이름(DIRECTIONS)과 .png를 붙인다
## --colors: 찾을 색 (쉼표로 구분)
## --origin: 그림 안의 기준점 픽셀 (Sprite2D offset의 부호를 바꾼 값)

## FacingSprite의 방향 순서 (Facing 규칙: 동쪽부터 화면 시계 방향)
const DIRECTIONS: PackedStringArray = ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]


func _initialize() -> void:
	var prefix: String = ""
	var colors: PackedStringArray = []
	var origin: Vector2 = Vector2.ZERO
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
		elif arg.begins_with("--colors="):
			colors = arg.trim_prefix("--colors=").to_lower().split(",")
		elif arg.begins_with("--origin="):
			var parts: PackedStringArray = arg.trim_prefix("--origin=").split(",")
			origin = Vector2(float(parts[0]), float(parts[1]))
	if prefix.is_empty() or colors.is_empty():
		printerr("--prefix와 --colors가 필요합니다.")
		quit(2)
		return
	var muzzles: PackedStringArray = []
	for direction: String in DIRECTIONS:
		var image: Image = (load(prefix + direction + ".png") as Texture2D).get_image()
		var cluster: Array[Vector2i] = _largest_cluster(image, colors)
		if cluster.is_empty():
			print("%s: 없음" % direction)
			muzzles.append("Vector2(?, ?)")
			continue
		var sum: Vector2 = Vector2.ZERO
		for p: Vector2i in cluster:
			sum += Vector2(p) + Vector2(0.5, 0.5)
		var point: Vector2 = (sum / cluster.size() - origin).round()
		print("%s: %d픽셀 → %s" % [direction, cluster.size(), point])
		muzzles.append("Vector2(%d, %d)" % [point.x, point.y])
	print("direction_muzzles = Array[Vector2]([%s])" % ", ".join(muzzles))
	quit()


func _largest_cluster(image: Image, colors: PackedStringArray) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var best: Array[Vector2i] = []
	for y: int in image.get_height():
		for x: int in image.get_width():
			var start: Vector2i = Vector2i(x, y)
			if seen.has(start) or not _matches(image, start, colors):
				continue
			var cluster: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				cluster.append(p)
				for d: Vector2i in NEIGHBORS:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= image.get_width() or q.y >= image.get_height():
						continue
					if seen.has(q) or not _matches(image, q, colors):
						continue
					seen[q] = true
					stack.append(q)
			if cluster.size() > best.size():
				best = cluster
	return best


func _matches(image: Image, p: Vector2i, colors: PackedStringArray) -> bool:
	var c: Color = image.get_pixelv(p)
	return c.a > 0.0 and colors.has(c.to_html(false))
