extends SceneTree
## UI 그림 후보의 스크립트 검사: 확실히 틀린 것을 거르고 숫자를 낸다. 고르기(보고 견주기)는 사람·에이전트가 한다.
## ui-designer 에이전트(.claude/agents/ui-designer.md "붙이기" 2)가 쓴다. Python 없이 Godot Image로 돈다.
##
## 실행 (저장소 폴더에서):
##   bash tools/godot.sh --headless --path . -s tools/ui_gen/check_ui_image.gd -- --kind=<종류> [옵션] <후보.png> ...
## 종류 (--kind):
##   icon        아이콘 한 장
##   icon_sheet  아이콘 여러 개를 한 장에 그린 것. 불투명 조각으로 나눠 아이콘마다 본다 (--expect=<수>)
##   frame       9-slice 창 틀. 바깥 투명, 가운데 고른 판. 9-slice 여백을 낸다
##   button      버튼 상태 그림들 (넘긴 PNG들이 한 벌: 보통·올림·눌림·비활성 순)
## 옵션:
##   --ref=<png>[@x,y,w,h]  색을 견줄 기준 그림 (자를 상자를 줄 수 있다). 여러 번 줄 수 있다. 상자 안 픽셀을 모두 센다 (틀 돌처럼)
##   --ref-icon=<png>@x,y,w,h  칸 안 아이콘을 기준으로 쓸 때. 자른 상자의 테두리 색(빈 칸 배경)과 가까운 픽셀은 뺀다
##   --between              기준이 둘일 때, 후보 밝기가 두 기준 밝기의 사이(± LUMA_BETWEEN_TOL)여야 통과 (틀 돌 색 "그 사이" 같은 결정)
##   --expect=<수>          icon_sheet의 아이콘 수
##   --skip-color=<1,6>     icon_sheet에서 색 판정을 하지 않을 아이콘 번호 (기준에 없는 새 색. 숫자는 출력한다)
##   --final=<px>           최종 그림의 긴 변 (icon 기본 ICON_FINAL_PX). 물건이 이보다 작으면 늘려야 해서 버림
##   --center-from-theme    frame의 가운데를 그림에서 쓰지 않고 테마가 그릴 때 (NinePatchRect draw_center = false). 가운데 판은 숫자만 내고 판정하지 않는다
##
## 판정 기준 (맨 위 상수):
##   투명 배경   바깥 테두리 BORDER_RING px의 BORDER_CLEAR_MIN 이상이 투명. 아니면 버림 (배경·체크무늬를 그려 넣음)
##   잘림        물건이 그림 가장자리에 닿으면 버림 (icon, icon_sheet)
##   크기        물건 긴 변이 최종 크기보다 작으면 버림 (늘리면 흐려진다). 비율은 자르고 맞추므로 보지 않는다
##   색          후보 주요 색 → 가장 가까운 기준 주요 색 거리의 무게 평균이 COLOR_DISTANCE_MAX 초과, 또는 밝기 차가 LUMA_DIFF_MAX 초과면 버림.
##               기준이 여럿이면 가장 가까운 기준과 견준다
##   9-slice 틀  가운데가 판이면: 밝기 표준편차 CENTER_STD_MAX 초과, 또는 반투명 픽셀(알파 < CENTER_SOLID_ALPHA)이 CENTER_HOLE_MAX 넘게 있으면 버림
##               (늘리면 얼룩이 늘어난다). 가운데가 뚫렸으면(투명) 판정하지 않는다 (판은 테마가 그린다).
##               가장자리 모양(바깥 윤곽·띠 두께)이 모서리에서 변 길이의 CORNER_MAX_RATIO보다 안쪽까지 달라지면 버림 (가운데 혹·장식)
##   번짐       (경고만) 아이콘 둘레에 물건에서 떨어진 흐린 반투명 픽셀이 불투명의 HAZE_WARN_RATIO를 넘으면 경고. 버릴지는 눈으로 본다
##   버튼 상태   크기가 다르거나 물건 상자가 BUTTON_SHIFT_MAX px 넘게 어긋나면 버림
## 출력: 후보마다 "== <파일>" 다음 줄마다 항목과 숫자, 마지막에 "판정: 통과" 또는 "판정: 버림 (<이유>; ...)".
##   frame은 "9-slice 여백 (왼,위,오,아래)"를 낸다 (그림을 잘라 낸 뒤의 픽셀).
## 종료 코드: 0 = 검사함 (판정은 출력에), 2 = 인자 오류·읽기 실패

const Lib: GDScript = preload("res://tools/ui_gen/ui_image_lib.gd")

const BORDER_RING: int = 4
const BORDER_CLEAR_MIN: float = 0.95
const ICON_FINAL_PX: int = 144
const COLOR_DISTANCE_MAX: float = 40.0
const LUMA_DIFF_MAX: float = 0.10
const LUMA_BETWEEN_TOL: float = 0.03
## 기준 그림을 자른 상자에서 빈 칸 배경으로 보고 뺄 거리
const REF_BG_DISTANCE: float = 40.0
## 9-slice: 가운데 판으로 볼 색 거리 (가운데 색에서)
const PANEL_DISTANCE: float = 30.0
const CENTER_STD_MAX: float = 0.025
## 9-slice: 가운데 판에서 이 알파보다 낮은 픽셀은 반투명 자국으로 센다
const CENTER_SOLID_ALPHA: int = 250
const CENTER_HOLE_MAX: float = 0.01
const CORNER_MAX_RATIO: float = 0.30
## 9-slice: 가장자리 모양이 "같다"로 볼 허용 (px과 띠 두께 비율 중 큰 것)
const EDGE_TOL_MIN_PX: int = 3
const EDGE_TOL_RATIO: float = 0.12
## 9-slice 여백에 더할 픽셀
const MARGIN_PAD: int = 2
const BUTTON_SHIFT_MAX: int = 3
## 아이콘 번짐: 불투명 픽셀에서 이 거리(px)보다 먼 반투명 픽셀을 센다. 불투명 수의 HAZE_WARN_RATIO를 넘으면 경고 (판정은 눈으로)
const HAZE_DISTANCE: int = 3
const HAZE_MIN_ALPHA: int = 8
const HAZE_WARN_RATIO: float = 0.01
const NO_COLORS: Array[Color] = []

var _refs: Array[Dictionary] = []


func _initialize() -> void:
	var kind: String = ""
	var between: bool = false
	var center_from_theme: bool = false
	var expect: int = 0
	var skip_color: Array[int] = []
	var final_px: int = ICON_FINAL_PX
	var paths: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
		elif arg.begins_with("--ref="):
			if not _add_ref(arg.trim_prefix("--ref="), false):
				quit(2)
				return
		elif arg.begins_with("--ref-icon="):
			if not _add_ref(arg.trim_prefix("--ref-icon="), true):
				quit(2)
				return
		elif arg == "--center-from-theme":
			center_from_theme = true
		elif arg == "--between":
			between = true
		elif arg.begins_with("--expect="):
			expect = arg.trim_prefix("--expect=").to_int()
		elif arg.begins_with("--skip-color="):
			for part: String in arg.trim_prefix("--skip-color=").split(",", false):
				skip_color.append(part.to_int())
		elif arg.begins_with("--final="):
			final_px = arg.trim_prefix("--final=").to_int()
		elif arg.begins_with("--"):
			printerr("모르는 인자: %s" % arg)
			quit(2)
			return
		else:
			paths.append(arg)
	if not kind in ["icon", "icon_sheet", "frame", "button"] or paths.is_empty():
		printerr("사용법: -- --kind=<icon|icon_sheet|frame|button> [--ref=<png>[@x,y,w,h]]... [--ref-icon=<png>@x,y,w,h]... [--between] [--expect=<수>] [--skip-color=<번호,...>] [--final=<px>] <후보.png> ...")
		quit(2)
		return
	if between and _refs.size() != 2:
		printerr("--between은 --ref가 둘일 때만 쓴다")
		quit(2)
		return
	for ref: Dictionary in _refs:
		print("기준: %s 주요 색 %s, 밝기 %.3f" % [ref.name, _colors_text(ref.dominant), ref.luma])
	if kind == "button":
		_check_button(paths)
		quit(0)
		return
	for path: String in paths:
		var image: Image = Lib.load_rgba(path)
		if image == null:
			printerr("읽지 못함: %s" % path)
			quit(2)
			return
		print("== %s (%d×%d, 알파 %s)" % [path, image.get_width(), image.get_height(), "있음" if Lib.file_has_alpha(path) else "없음"])
		var reasons: PackedStringArray = PackedStringArray()
		_check_transparent(image, reasons)
		match kind:
			"icon":
				_check_icon(image, Lib.alpha_bbox(image), "", final_px, between, false, reasons)
			"icon_sheet":
				_check_sheet(image, expect, skip_color, final_px, between, reasons)
			"frame":
				_check_frame(image, between, center_from_theme, reasons)
		print("  판정: %s" % ("통과" if reasons.is_empty() else "버림 (%s)" % "; ".join(reasons)))
	quit(0)


## --ref 값 하나를 읽어 주요 색·밝기를 기억한다. skip_slot_bg면 자른 상자의 테두리 색(빈 칸 배경)과 가까운 픽셀을 뺀다
func _add_ref(value: String, skip_slot_bg: bool) -> bool:
	var path: String = value
	var rect: Rect2i = Rect2i()
	if value.contains("@"):
		path = value.get_slice("@", 0)
		var nums: PackedStringArray = value.get_slice("@", 1).split(",")
		if nums.size() != 4:
			printerr("--ref 상자는 x,y,w,h다: %s" % value)
			return false
		rect = Rect2i(nums[0].to_int(), nums[1].to_int(), nums[2].to_int(), nums[3].to_int())
	var image: Image = Lib.load_rgba(path)
	if image == null:
		printerr("기준 그림을 읽지 못함: %s" % path)
		return false
	var exclude: Array[Color] = []
	if not rect.has_area():
		rect = Rect2i(Vector2i.ZERO, image.get_size())
	elif skip_slot_bg:
		exclude.append(Lib.border_median_color(image, rect))
	var stats: Dictionary = Lib.mean_stats(image, rect, exclude, REF_BG_DISTANCE)
	_refs.append({
		name = value.get_file(),
		dominant = Lib.dominant_colors(image, rect, exclude, REF_BG_DISTANCE),
		luma = stats.luma,
	})
	return true


func _check_transparent(image: Image, reasons: PackedStringArray) -> void:
	var clear: float = Lib.border_transparent_ratio(image, BORDER_RING)
	var line: String = "  투명 배경: 바깥 %dpx 테두리의 %.0f%%가 투명" % [BORDER_RING, clear * 100.0]
	if clear < BORDER_CLEAR_MIN:
		var what: String = "체크무늬를 그려 넣음" if Lib.border_looks_checkered(image, BORDER_RING) else "배경을 그려 넣음"
		line += " → 버림 (%s)" % what
		reasons.append("투명 배경 아님 (%s)" % what)
	print(line)


## 아이콘 하나 (box는 그림 안의 물건 상자). label은 묶음 안 번호
func _check_icon(image: Image, box: Rect2i, label: String, final_px: int, between: bool, skip_color: bool, reasons: PackedStringArray) -> void:
	var head: String = "  %s" % label if not label.is_empty() else "  물건"
	if not box.has_area():
		print("%s: 불투명 픽셀이 없음 → 버림" % head)
		reasons.append("%s 비어 있음" % label)
		return
	var long_side: int = maxi(box.size.x, box.size.y)
	var image_rect: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	var touches: bool = box.position.x == 0 or box.position.y == 0 or box.end.x == image_rect.end.x or box.end.y == image_rect.end.y
	var mask_count: int = Lib.mean_stats(image, box).count
	var fill: float = float(mask_count) / (box.size.x * box.size.y)
	print("%s: 상자 %s, 긴 변 %dpx (최종 %dpx의 %.1f배), 상자 안 채움 %.0f%%%s" % [head, box, long_side, final_px, float(long_side) / final_px, fill * 100.0, ", 그림 가장자리에 닿음" if touches else ""])
	if touches:
		reasons.append("%s 잘림 (그림 가장자리에 닿음)" % label if not label.is_empty() else "잘림 (그림 가장자리에 닿음)")
	if long_side < final_px:
		reasons.append("%s 너무 작음 (%dpx < %dpx)" % [label, long_side, final_px])
	var haze: int = _haze_pixels(image, box.grow(roundi(long_side * 0.1)).intersection(image_rect))
	var haze_ratio: float = float(haze) / maxi(mask_count, 1)
	print("%s 번짐: 물건에서 %dpx 넘게 떨어진 반투명 픽셀 %d개 (불투명의 %.1f%%)%s" % [head, HAZE_DISTANCE, haze, haze_ratio * 100.0, " → 경고 (눈으로 확인)" if haze_ratio > HAZE_WARN_RATIO else ""])
	_check_color(image, box, PackedByteArray(), head, between, skip_color, reasons)


## 불투명 픽셀에서 HAZE_DISTANCE 넘게 떨어진 반투명 픽셀(알파 HAZE_MIN_ALPHA~127) 수. 배경을 지우다 남은 흐린 번짐을 센다
func _haze_pixels(image: Image, rect: Rect2i) -> int:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var a: int = data[(y * w + x) * 4 + 3]
			if a < HAZE_MIN_ALPHA or a >= Lib.OPAQUE_ALPHA:
				continue
			var near: bool = false
			for dy: int in range(maxi(0, y - HAZE_DISTANCE), mini(h, y + HAZE_DISTANCE + 1)):
				for dx: int in range(maxi(0, x - HAZE_DISTANCE), mini(w, x + HAZE_DISTANCE + 1)):
					if data[(dy * w + dx) * 4 + 3] >= Lib.OPAQUE_ALPHA:
						near = true
						break
				if near:
					break
			if not near:
				count += 1
	return count


func _check_sheet(image: Image, expect: int, skip_color: Array[int], final_px: int, between: bool, reasons: PackedStringArray) -> void:
	var boxes: Array[Rect2i] = Lib.components(image)
	print("  조각: %d개%s" % [boxes.size(), " (기대 %d)" % expect if expect > 0 else ""])
	if expect > 0 and boxes.size() != expect:
		reasons.append("아이콘 수 %d개 (기대 %d. 배경이 있거나 아이콘이 붙음)" % [boxes.size(), expect])
		return
	for i: int in boxes.size():
		_check_icon(image, boxes[i], "아이콘 %d" % (i + 1), final_px, between, skip_color.has(i + 1), reasons)


## 색: 주요 색 거리와 밝기 차. 기준이 여럿이면 가장 가까운 기준과 견준다. between이면 밝기가 두 기준 사이여야 한다
func _check_color(image: Image, rect: Rect2i, mask: PackedByteArray, head: String, between: bool, skip: bool, reasons: PackedStringArray) -> void:
	var dominant: Array[Dictionary] = Lib.dominant_colors(image, rect, NO_COLORS, 0.0, mask)
	var stats: Dictionary = Lib.mean_stats(image, rect, NO_COLORS, 0.0, mask)
	var line: String = "%s 색: 주요 색 %s, 밝기 %.3f" % [head, _colors_text(dominant), stats.luma]
	if _refs.is_empty():
		print(line + " (기준 없음, 판정 안 함)")
		return
	var best: Dictionary = {}
	var best_distance: float = INF
	for ref: Dictionary in _refs:
		var d: float = Lib.palette_distance(dominant, ref.dominant)
		if d < best_distance:
			best_distance = d
			best = ref
	var luma_diff: float = stats.luma - best.luma
	line += ", 가장 가까운 기준 %s: 색 거리 %.1f (최대 %.0f), 밝기 차 %+.3f" % [best.name, best_distance, COLOR_DISTANCE_MAX, luma_diff]
	var failed: PackedStringArray = PackedStringArray()
	if best_distance > COLOR_DISTANCE_MAX:
		failed.append("색 거리 %.1f" % best_distance)
	if between:
		var low: float = minf(_refs[0].luma, _refs[1].luma) - LUMA_BETWEEN_TOL
		var high: float = maxf(_refs[0].luma, _refs[1].luma) + LUMA_BETWEEN_TOL
		line += ", 두 기준 사이 범위 %.3f~%.3f" % [low, high]
		if stats.luma < low or stats.luma > high:
			failed.append("밝기 %.3f가 두 기준 사이 밖" % stats.luma)
	elif absf(luma_diff) > LUMA_DIFF_MAX:
		failed.append("밝기 차 %+.3f" % luma_diff)
	if skip:
		print(line + " (새 색이라 판정 안 함)")
		return
	if not failed.is_empty():
		line += " → 버림"
		reasons.append("%s %s" % [head.strip_edges(), ", ".join(failed)])
	print(line)


## 9-slice 틀: 잘라 낸 뒤 가운데 판 색을 잡고, 네 변의 모양이 어디까지 달라지는지 보고 여백을 낸다
func _check_frame(source: Image, between: bool, center_from_theme: bool, reasons: PackedStringArray) -> void:
	var bbox: Rect2i = Lib.alpha_bbox(source)
	if not bbox.has_area():
		reasons.append("비어 있음")
		return
	var image: Image = source.get_region(bbox)
	var w: int = image.get_width()
	var h: int = image.get_height()
	var data: PackedByteArray = image.get_data()
	var center: Rect2i = Rect2i(w / 2 - w / 40, h / 2 - h / 40, maxi(1, w / 20), maxi(1, h / 20))
	var center_stats: Dictionary = Lib.mean_stats(image, center)
	# 가운데가 거의 투명하면 뚫린 틀이다 (판은 테마가 그린다)
	var open_center: bool = center_stats.count < center.get_area() / 2
	var panel_color: Color = center_stats.color
	# 띠 안쪽으로 볼 픽셀: 가운데 판 색이거나 투명
	var is_panel: PackedByteArray = PackedByteArray()
	is_panel.resize(w * h)
	for p: int in w * h:
		var i: int = p * 4
		if data[i + 3] < Lib.OPAQUE_ALPHA:
			is_panel[p] = 1
		elif not open_center and Vector3(data[i] - panel_color.r8, data[i + 1] - panel_color.g8, data[i + 2] - panel_color.b8).length() < PANEL_DISTANCE:
			is_panel[p] = 1
	print("  잘라 낸 크기: %d×%d (원본 상자 %s), 가운데 %s" % [w, h, bbox, "뚫림 (투명)" if open_center else "판 색 " + Lib.hex(panel_color)])
	# 변마다: 바깥 윤곽(처음 불투명)과 띠 두께(가운데 판이 시작되는 곳)
	var top: Dictionary = _edge_profile(image, is_panel, true, false)
	var bottom: Dictionary = _edge_profile(image, is_panel, true, true)
	var left: Dictionary = _edge_profile(image, is_panel, false, false)
	var right: Dictionary = _edge_profile(image, is_panel, false, true)
	var margin_l: int = maxi(maxi(top.start_extent, bottom.start_extent), left.band_max) + MARGIN_PAD
	var margin_r: int = maxi(maxi(top.end_extent, bottom.end_extent), right.band_max) + MARGIN_PAD
	var margin_t: int = maxi(maxi(left.start_extent, right.start_extent), top.band_max) + MARGIN_PAD
	var margin_b: int = maxi(maxi(left.end_extent, right.end_extent), bottom.band_max) + MARGIN_PAD
	for pair: Array in [["위", top, w], ["아래", bottom, w], ["왼", left, h], ["오른", right, h]]:
		var edge: Dictionary = pair[1]
		var length: int = pair[2]
		var worst: float = float(maxi(edge.start_extent, edge.end_extent)) / length
		var line: String = "  %s 변: 띠 두께 가운데값 %dpx (가운데 구간 %d~%d), 바깥 윤곽 흔들림 %dpx, 모양이 달라지는 곳 처음 %dpx·끝 %dpx (변 길이의 %.0f%%)" % [pair[0], edge.band_median, edge.band_min, edge.band_max, edge.silhouette_range, edge.start_extent, edge.end_extent, worst * 100.0]
		if worst > CORNER_MAX_RATIO:
			line += " → 버림"
			reasons.append("%s 변 가운데까지 모양이 달라짐 (혹·장식)" % pair[0])
		print(line)
	var inner: Rect2i = Rect2i(margin_l, margin_t, w - margin_l - margin_r, h - margin_t - margin_b)
	print("  9-slice 여백 (왼,위,오,아래): %d,%d,%d,%d" % [margin_l, margin_t, margin_r, margin_b])
	if not inner.has_area():
		reasons.append("가운데 구간이 없음")
		return
	_check_center(image, inner, open_center, center_from_theme, reasons)
	# 돌 색: 판이 아닌 불투명 픽셀
	var stone_mask: PackedByteArray = PackedByteArray()
	stone_mask.resize(w * h)
	for p: int in w * h:
		stone_mask[p] = 1 if data[p * 4 + 3] >= Lib.OPAQUE_ALPHA and is_panel[p] == 0 else 0
	_check_color(image, Rect2i(0, 0, w, h), stone_mask, "  틀 돌", between, false, reasons)


## 한 변의 모양. horizontal이면 위·아래 변(열마다), 아니면 왼·오른 변(줄마다). far면 아래·오른 변.
## 돌려주는 것: band_median/min/max(가운데 구간의 띠 두께), silhouette_range, start_extent·end_extent(모양이 가운데값과 다른 마지막 자리 + 1)
func _edge_profile(image: Image, is_panel: PackedByteArray, horizontal: bool, far: bool) -> Dictionary:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var data: PackedByteArray = image.get_data()
	var length: int = w if horizontal else h
	var depth: int = (h if horizontal else w) / 2
	var band: PackedInt32Array = PackedInt32Array()
	var silhouette: PackedInt32Array = PackedInt32Array()
	band.resize(length)
	silhouette.resize(length)
	for t: int in length:
		band[t] = -1
		silhouette[t] = -1
		for d: int in depth:
			var x: int = t if horizontal else (w - 1 - d if far else d)
			var y: int = (h - 1 - d if far else d) if horizontal else t
			var p: int = y * w + x
			if silhouette[t] < 0 and data[p * 4 + 3] >= Lib.OPAQUE_ALPHA:
				silhouette[t] = d
			# 판이 3픽셀 이어지면 띠가 끝난 것으로 본다
			if silhouette[t] >= 0 and d > silhouette[t] and is_panel[p] == 1 and d + 2 < depth:
				var x2: int = t if horizontal else (w - 1 - (d + 2) if far else d + 2)
				var y2: int = (h - 1 - (d + 2) if far else d + 2) if horizontal else t
				if is_panel[y2 * w + x2] == 1:
					band[t] = d
					break
	# 가운데 절반 구간의 가운데값
	var middle_band: Array[int] = []
	var middle_sil: Array[int] = []
	for t: int in range(length / 4, length * 3 / 4):
		if band[t] >= 0:
			middle_band.append(band[t])
		if silhouette[t] >= 0:
			middle_sil.append(silhouette[t])
	if middle_band.is_empty():
		return {band_median = depth, band_min = depth, band_max = depth, silhouette_range = 0, start_extent = length / 2, end_extent = length / 2}
	middle_band.sort()
	middle_sil.sort()
	var med_band: int = middle_band[middle_band.size() / 2]
	var med_sil: int = middle_sil[middle_sil.size() / 2] if not middle_sil.is_empty() else 0
	var tol: int = maxi(EDGE_TOL_MIN_PX, roundi(EDGE_TOL_RATIO * med_band))
	var start_extent: int = 0
	var end_extent: int = 0
	for t: int in length:
		var differs: bool = band[t] < 0 or absi(band[t] - med_band) > tol or silhouette[t] < 0 or absi(silhouette[t] - med_sil) > tol
		if not differs:
			continue
		if t < length / 2:
			start_extent = maxi(start_extent, t + 1)
		else:
			end_extent = maxi(end_extent, length - t)
	# 여백 밖(가운데 구간)의 띠 두께 범위
	var band_min: int = depth
	var band_max: int = 0
	for t: int in range(start_extent, length - end_extent):
		if band[t] >= 0:
			band_min = mini(band_min, band[t])
			band_max = maxi(band_max, band[t])
	var sil_min: int = depth
	var sil_max: int = 0
	for t: int in range(start_extent, length - end_extent):
		if silhouette[t] >= 0:
			sil_min = mini(sil_min, silhouette[t])
			sil_max = maxi(sil_max, silhouette[t])
	return {
		band_median = med_band,
		band_min = band_min,
		band_max = band_max,
		silhouette_range = maxi(0, sil_max - sil_min),
		start_extent = start_extent,
		end_extent = end_extent,
	}


## 버튼 상태 그림들: 같은 크기, 같은 자리
func _check_button(paths: PackedStringArray) -> void:
	var reasons: PackedStringArray = PackedStringArray()
	var first_size: Vector2i = Vector2i.ZERO
	var first_box: Rect2i = Rect2i()
	print("== 버튼 한 벌: %s" % ", ".join(paths))
	for path: String in paths:
		var image: Image = Lib.load_rgba(path)
		if image == null:
			reasons.append("읽지 못함 %s" % path.get_file())
			continue
		var box: Rect2i = Lib.alpha_bbox(image)
		print("  %s: %d×%d, 물건 상자 %s" % [path.get_file(), image.get_width(), image.get_height(), box])
		_check_transparent(image, reasons)
		if first_size == Vector2i.ZERO:
			first_size = image.get_size()
			first_box = box
			continue
		if image.get_size() != first_size:
			reasons.append("%s 크기가 다름" % path.get_file())
		var shift: int = maxi(absi(box.position.x - first_box.position.x), absi(box.position.y - first_box.position.y))
		shift = maxi(shift, maxi(absi(box.end.x - first_box.end.x), absi(box.end.y - first_box.end.y)))
		if shift > BUTTON_SHIFT_MAX:
			reasons.append("%s 자리가 %dpx 어긋남" % [path.get_file(), shift])
	print("  판정: %s" % ("통과" if reasons.is_empty() else "버림 (%s)" % "; ".join(reasons)))


func _colors_text(colors: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: Dictionary in colors:
		parts.append("%s %.0f%%" % [Lib.hex(c.color), c.weight * 100.0])
	return ", ".join(parts)


## 9-slice 가운데 구간: 판이면 고른지와 반투명 자국, 뚫렸으면 그렇다고만 쓴다
func _check_center(image: Image, inner: Rect2i, open_center: bool, center_from_theme: bool, reasons: PackedStringArray) -> void:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var holes: int = 0
	var clear: int = 0
	for y: int in range(inner.position.y, inner.end.y):
		for x: int in range(inner.position.x, inner.end.x):
			var a: int = data[(y * w + x) * 4 + 3]
			if a < CENTER_SOLID_ALPHA:
				holes += 1
			if a < 26:
				clear += 1
	var area: float = float(inner.get_area())
	var stats: Dictionary = Lib.mean_stats(image, inner)
	var line: String = "  가운데 구간: 투명 %.1f%%, 반투명 자국(알파 < %d) %.1f%%, 불투명 픽셀 밝기 평균 %.3f, 표준편차 %.4f" % [clear / area * 100.0, CENTER_SOLID_ALPHA, (holes - clear) / area * 100.0, stats.luma, stats.luma_std]
	if open_center and clear / area > 0.95:
		print(line + " (뚫린 가운데. 판은 테마가 그린다)")
		return
	if center_from_theme:
		print(line + " (가운데는 테마가 그리므로 판정 안 함)")
		return
	var failed: PackedStringArray = PackedStringArray()
	if stats.luma_std > CENTER_STD_MAX:
		failed.append("가운데 판이 고르지 않음 (표준편차 %.4f > %.3f)" % [stats.luma_std, CENTER_STD_MAX])
	if float(holes) / area > CENTER_HOLE_MAX:
		failed.append("가운데 판에 반투명 자국 %.1f%%" % (float(holes) / area * 100.0))
	if not failed.is_empty():
		line += " → 버림"
		reasons.append_array(failed)
	print(line)
