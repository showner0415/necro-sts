extends SceneTree
## 얕은 굴 PNG의 한 마리 자리를 무리 자리로 바꾼다 (계획 8a). 굴마다 바꿀 무리(ROOMS)만 적고, 칸은 스크립트가 고른다:
## 그 굴에서 바꿀 종(from)의 몬스터 칸 중 굴의 가운데 칸에 가장 가까운 칸 하나를 무리 색으로 칠하고, 나머지는 그 굴의 바닥 색으로 지운다.
## spot을 주면 그 칸(그 굴의 바닥)을 무리 자리로 쓴다. 적지 않은 굴과 종(박쥐 무리, 거미 자리 등)은 그대로 둔다. 같은 PNG면 결과가 늘 같다.
## 이미 바꾼 PNG(바꿀 굴에 from 종이 없음)면 그 굴은 건너뛰고 알린다.
## 입력은 무리 배치 전(8a 전) PNG다. 지금 저장소의 PNG는 이미 바꾼 것이므로, 처음부터 다시 만들려면 그 PNG를 꺼내 --in으로 준다:
##   git show 54acb2e:art_src/maps/shallow_cave.png > <임시 경로>/before.png
##
## 미리보기: bash tools/godot.sh --headless --path . -s tools/map_png/make_pack_layout.gd -- --in=<입력 PNG> --out=<PNG 경로> --preview=<PNG 경로>
##   (--in을 주면 원본 대신 그 파일을 읽고, --out을 주면 원본 대신 그 파일에 쓴다. --preview는 3배로 키우고 무리 자리를 흰 테두리로 둘러싼 그림)
## 원본에 쓰기: bash tools/godot.sh --headless --path . -s tools/map_png/make_pack_layout.gd -- --in=<임시 경로>/before.png
## 그다음 씬을 다시 만든다 (map-edit 스킬 1·2)

const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
## 굴의 가운데 칸(변환 출력의 굴 목록) → 바꿀 종(from)과 무리 색 (docs/maps/map_png_rules.md). 사용자 결정 2026-11-14 (docs/game-design.md "몬스터 무리"의 얕은 굴 무리 배치)
const ROOMS: Array[Dictionary] = [
	{"name": "입구 굴 (초반)", "center": Vector2i(70, 122), "from": ["rat"], "pack": "e8b796"},
	{"name": "버섯 굴", "center": Vector2i(40, 44), "from": ["rat"], "pack": "e8b796"},
	{"name": "쥐 둥지", "center": Vector2i(125, 61), "from": ["rat"], "pack": "ead4aa"},
	{"name": "갈림 굴", "center": Vector2i(201, 124), "from": ["rat"], "pack": "e8b796"},
	{"name": "물웅덩이 굴", "center": Vector2i(119, 185), "from": ["rat"], "pack": "e8b796"},
	# 빛 드는 굴은 합류 굴 쪽 입구에서 멧돼지가 먼저 보여야 한다 (scenario_shallow_cave 5-2). 굴 가운데 쪽 자리는 화면 밖이라,
	# 입구 가운데에서 3D 화면 안이고(가로 236·세로 107px, 화면 반 - 여유 304·164 안), 입구에서 273px(흩어 놓기 48px를 빼도 감지 150 밖)인 칸을 직접 준다
	{"name": "빛 드는 굴", "center": Vector2i(422, 51), "from": ["boar"], "pack": "d77643", "spot": Vector2i(392, 55)},
	{"name": "동굴 입구", "center": Vector2i(428, 149), "from": ["boar"], "pack": "d77643"},
	{"name": "진흙 굴", "center": Vector2i(418, 205), "from": ["boar"], "pack": "b86f50"},
]
## 지운 칸에 칠할 굴 바닥 색 (굴 글자 → 색)
const FLOOR_COLORS: Dictionary = {"1": "265c42", "2": "733e39", "b": "124e89"}
const PREVIEW_SCALE: int = 3
## 미리보기에서 무리 자리를 둘러싸는 테두리 반지름 (칸)
const PREVIEW_RING: int = 3


func _initialize() -> void:
	var out_path: String = ProjectSettings.globalize_path(MAP_PNG)
	var preview_path: String = ""
	var in_path: String = ProjectSettings.globalize_path(MAP_PNG)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--in="):
			in_path = arg.trim_prefix("--in=")
		elif arg.begins_with("--preview="):
			preview_path = arg.trim_prefix("--preview=")
	var image: Image = Image.load_from_file(in_path)
	var layout: MapLayout = MapLayout.from_image(image)
	var spots: Array[Vector2i] = []
	for room_plan: Dictionary in ROOMS:
		var room: int = layout.room_at(room_plan.center)
		var cells: Array[Vector2i] = []
		for o: Dictionary in layout.objects:
			if o.object in room_plan.from and layout.room_at(o.cell) == room:
				cells.append(o.cell)
		if room < 0 or cells.is_empty():
			print("건너뜀: %s (굴 %d, 바꿀 몬스터 없음)" % [room_plan.name, room])
			continue
		var middle: Vector2 = layout.rooms[room].center
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(middle) < Vector2(b).distance_to(middle))
		var floor_color: Color = Color.html(FLOOR_COLORS[layout.rooms[room].char])
		for cell: Vector2i in cells:
			image.set_pixelv(cell, floor_color)
		var spot: Vector2i = room_plan.get("spot", cells[0])
		if layout.room_at(spot) != room:
			print("멈춤: %s의 자리 %s가 그 굴 바닥이 아님" % [room_plan.name, spot])
			quit(1)
			return
		image.set_pixelv(spot, Color.html(room_plan.pack))
		spots.append(spot)
		print("%s: %s %d마리 → 무리 자리 %s (%s)" % [room_plan.name, room_plan.from, cells.size(), spot, room_plan.pack])
	image.save_png(out_path)
	print("저장: %s" % out_path)
	if not preview_path.is_empty():
		_save_preview(image, spots, preview_path)
	quit()


## 3배로 키우고 무리 자리를 흰 테두리로 둘러싼다.
func _save_preview(image: Image, spots: Array[Vector2i], path: String) -> void:
	var preview: Image = image.duplicate()
	preview.convert(Image.FORMAT_RGBA8)
	preview.resize(image.get_width() * PREVIEW_SCALE, image.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	for spot: Vector2i in spots:
		var center: Vector2i = spot * PREVIEW_SCALE + Vector2i.ONE * (PREVIEW_SCALE / 2)
		var radius: int = PREVIEW_RING * PREVIEW_SCALE
		for d: int in range(-radius, radius + 1):
			for edge: Vector2i in [Vector2i(d, -radius), Vector2i(d, radius), Vector2i(-radius, d), Vector2i(radius, d)]:
				var p: Vector2i = center + edge
				if p.x >= 0 and p.y >= 0 and p.x < preview.get_width() and p.y < preview.get_height():
					preview.set_pixelv(p, Color.WHITE)
	preview.save_png(path)
	print("미리보기: %s" % path)
