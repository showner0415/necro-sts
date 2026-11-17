extends RefCounted
## UI 그림 검사(check_ui_image.gd)와 다듬기(prepare_ui_image.gd)가 같이 쓰는 그림 계산.
## 픽셀은 get_data()의 RGBA8 바이트 배열로 읽는다 (get_pixel보다 훨씬 빠르다).
## 색 거리는 0~255 RGB 공간의 유클리드 거리, 밝기는 0~1 (sRGB 값에 Rec.709 가중치).

## 불투명으로 셀 알파 (0~255)
const OPAQUE_ALPHA: int = 128
## 주요 색을 셀 때 한 채널을 몇 단계로 나누는지
const QUANT_LEVELS: int = 16
## 주요 색끼리 이 거리보다 가까우면 하나로 합친다
const MERGE_DISTANCE: float = 28.0
## 주요 색으로 돌려주는 최대 수
const DOMINANT_COUNT: int = 5
## 조각 나누기: 이보다 작은 조각(그림 넓이에 대한 비율)은 티끌로 보고 버린다
const SPECK_AREA_RATIO: float = 0.0004
## 조각 나누기: 상자끼리 이 거리(픽셀, 그림 짧은 변에 대한 비율) 안이면 한 물건으로 합친다 (물약 마개처럼 떨어진 조각)
const MERGE_GAP_RATIO: float = 0.02


static func load_rgba(path: String) -> Image:
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


## 그림 파일에 알파 채널이 있는지 (RGBA로 바꾸기 전 원본 기준)
static func file_has_alpha(path: String) -> bool:
	var image: Image = Image.load_from_file(path)
	if image == null:
		return false
	return image.detect_alpha() != Image.ALPHA_NONE


static func luma_of(r: float, g: float, b: float) -> float:
	return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


static func distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 255.0


static func hex(color: Color) -> String:
	return color.to_html(false)


## 알파가 threshold 이상인 픽셀을 모두 담는 상자. 없으면 크기 0
static func alpha_bbox(image: Image, threshold: int = OPAQUE_ALPHA) -> Rect2i:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y: int in h:
		var row: int = y * w * 4
		for x: int in w:
			if data[row + x * 4 + 3] >= threshold:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## 바깥 테두리 ring픽셀 두께에서 거의 투명한(알파 < 26) 픽셀의 비율 (0~1)
static func border_transparent_ratio(image: Image, ring: int) -> float:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var total: int = 0
	var clear: int = 0
	for y: int in h:
		for x: int in w:
			if x >= ring and x < w - ring and y >= ring and y < h - ring:
				continue
			total += 1
			if data[(y * w + x) * 4 + 3] < 26:
				clear += 1
	return float(clear) / maxi(total, 1)


## 테두리 ring픽셀이 두 색이 번갈아 나오는 체크무늬 같은지 (불투명 테두리에서만 의미가 있다)
static func border_looks_checkered(image: Image, ring: int) -> bool:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var lumas: Dictionary[int, int] = {}
	for x: int in w:
		for y: int in ring:
			var i: int = (y * w + x) * 4
			var key: int = roundi(luma_of(data[i], data[i + 1], data[i + 2]) * 20.0)
			lumas[key] = lumas.get(key, 0) + 1
	# 밝은 회색·흰색 두 단계가 거의 전부면 체크무늬로 본다
	var keys: Array[int] = lumas.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return lumas[a] > lumas[b])
	if keys.size() < 2:
		return false
	var top_two: int = lumas[keys[0]] + lumas[keys[1]]
	return float(top_two) / (w * ring) > 0.9 and keys[0] >= 14 and keys[1] >= 14 and keys[0] != keys[1]


## 상자 안 픽셀의 주요 색. 돌려주는 것: [{color: Color, weight: float(0~1)}] 무게 순.
## mask가 비어 있지 않으면 mask[y*w+x]가 1인 픽셀만 센다. exclude 색과 가까운 픽셀은 뺀다
static func dominant_colors(image: Image, rect: Rect2i, exclude: Array[Color] = [], exclude_distance: float = 0.0, mask: PackedByteArray = PackedByteArray()) -> Array[Dictionary]:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var bins: Dictionary[int, PackedInt64Array] = {}
	var step: int = 256 / QUANT_LEVELS
	var counted: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if not mask.is_empty() and mask[y * w + x] == 0:
				continue
			var i: int = (y * w + x) * 4
			if data[i + 3] < OPAQUE_ALPHA:
				continue
			var r: int = data[i]
			var g: int = data[i + 1]
			var b: int = data[i + 2]
			if not exclude.is_empty() and _near_any(r, g, b, exclude, exclude_distance):
				continue
			var key: int = (r / step) * QUANT_LEVELS * QUANT_LEVELS + (g / step) * QUANT_LEVELS + (b / step)
			if not bins.has(key):
				bins[key] = PackedInt64Array([0, 0, 0, 0])
			var bin: PackedInt64Array = bins[key]
			bin[0] += r
			bin[1] += g
			bin[2] += b
			bin[3] += 1
			bins[key] = bin
			counted += 1
	if counted == 0:
		return []
	var groups: Array[Dictionary] = []
	for bin: PackedInt64Array in bins.values():
		var n: float = float(bin[3])
		groups.append({color = Color(bin[0] / n / 255.0, bin[1] / n / 255.0, bin[2] / n / 255.0), count = n})
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	# 가까운 색끼리 무게 평균으로 합친다 (많은 쪽부터)
	var merged: Array[Dictionary] = []
	for group: Dictionary in groups:
		var joined: bool = false
		for target: Dictionary in merged:
			if distance(target.color, group.color) < MERGE_DISTANCE:
				var total: float = target.count + group.count
				target.color = target.color * (target.count / total) + group.color * (group.count / total)
				target.count = total
				joined = true
				break
		if not joined:
			merged.append({color = group.color, count = group.count})
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	var result: Array[Dictionary] = []
	for i: int in mini(DOMINANT_COUNT, merged.size()):
		result.append({color = merged[i].color, weight = merged[i].count / counted})
	return result


static func _near_any(r: int, g: int, b: int, colors: Array[Color], max_distance: float) -> bool:
	for color: Color in colors:
		if Vector3(r - color.r8, g - color.g8, b - color.b8).length() < max_distance:
			return true
	return false


## 상자 안 셀 픽셀의 평균 색과 밝기 평균·표준편차. 돌려주는 것: {color, luma, luma_std, count}
static func mean_stats(image: Image, rect: Rect2i, exclude: Array[Color] = [], exclude_distance: float = 0.0, mask: PackedByteArray = PackedByteArray()) -> Dictionary:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var sr: float = 0.0
	var sg: float = 0.0
	var sb: float = 0.0
	var sl: float = 0.0
	var sl2: float = 0.0
	var n: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if not mask.is_empty() and mask[y * w + x] == 0:
				continue
			var i: int = (y * w + x) * 4
			if data[i + 3] < OPAQUE_ALPHA:
				continue
			var r: int = data[i]
			var g: int = data[i + 1]
			var b: int = data[i + 2]
			if not exclude.is_empty() and _near_any(r, g, b, exclude, exclude_distance):
				continue
			var l: float = luma_of(r, g, b)
			sr += r
			sg += g
			sb += b
			sl += l
			sl2 += l * l
			n += 1
	if n == 0:
		return {color = Color(0, 0, 0, 0), luma = 0.0, luma_std = 0.0, count = 0}
	var mean_l: float = sl / n
	return {
		color = Color(sr / n / 255.0, sg / n / 255.0, sb / n / 255.0),
		luma = mean_l,
		luma_std = sqrt(maxf(0.0, sl2 / n - mean_l * mean_l)),
		count = n,
	}


## 후보의 주요 색이 기준 주요 색에서 얼마나 먼지: 후보 색마다 가장 가까운 기준 색까지의 거리를 무게로 평균
static func palette_distance(candidate: Array[Dictionary], reference: Array[Dictionary]) -> float:
	if candidate.is_empty() or reference.is_empty():
		return INF
	var total: float = 0.0
	var weight_sum: float = 0.0
	for c: Dictionary in candidate:
		var best: float = INF
		for r: Dictionary in reference:
			best = minf(best, distance(c.color, r.color))
		total += best * c.weight
		weight_sum += c.weight
	return total / maxf(weight_sum, 0.0001)


## 불투명 픽셀이 이어진 조각들의 상자. 티끌은 버리고, 가까운 조각은 합친다. 위 줄부터, 줄 안에서는 왼쪽부터 정렬
static func components(image: Image) -> Array[Rect2i]:
	var data: PackedByteArray = image.get_data()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * h)
	var boxes: Array[Rect2i] = []
	var areas: Array[int] = []
	var stack: PackedInt32Array = PackedInt32Array()
	for start: int in w * h:
		if seen[start] == 1 or data[start * 4 + 3] < OPAQUE_ALPHA:
			continue
		seen[start] = 1
		stack.append(start)
		var min_x: int = w
		var min_y: int = h
		var max_x: int = -1
		var max_y: int = -1
		var area: int = 0
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x: int = p % w
			var y: int = p / w
			area += 1
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
			if x > 0:
				_push_if_opaque(p - 1, data, seen, stack)
			if x < w - 1:
				_push_if_opaque(p + 1, data, seen, stack)
			if y > 0:
				_push_if_opaque(p - w, data, seen, stack)
			if y < h - 1:
				_push_if_opaque(p + w, data, seen, stack)
		boxes.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
		areas.append(area)
	var min_area: float = SPECK_AREA_RATIO * w * h
	var kept: Array[Rect2i] = []
	for i: int in boxes.size():
		if areas[i] >= min_area:
			kept.append(boxes[i])
	# 가까운 상자 합치기 (더 합칠 것이 없을 때까지)
	var gap: int = maxi(2, roundi(MERGE_GAP_RATIO * mini(w, h)))
	var changed: bool = true
	while changed:
		changed = false
		for i: int in kept.size():
			for j: int in range(i + 1, kept.size()):
				if kept[i].grow(gap).intersects(kept[j]):
					kept[i] = kept[i].merge(kept[j])
					kept.remove_at(j)
					changed = true
					break
			if changed:
				break
	# 줄로 묶어 정렬: 세로 가운데가 다른 상자 높이의 절반 안이면 같은 줄
	kept.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().y < b.get_center().y)
	var rows: Array[Array] = []
	for box: Rect2i in kept:
		if not rows.is_empty():
			var last: Rect2i = rows[rows.size() - 1][0]
			if absi(box.get_center().y - last.get_center().y) < maxi(last.size.y, box.size.y) / 2:
				rows[rows.size() - 1].append(box)
				continue
		rows.append([box])
	var ordered: Array[Rect2i] = []
	for row: Array in rows:
		row.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)
		for box: Rect2i in row:
			ordered.append(box)
	return ordered


static func _push_if_opaque(q: int, data: PackedByteArray, seen: PackedByteArray, stack: PackedInt32Array) -> void:
	if seen[q] == 0 and data[q * 4 + 3] >= OPAQUE_ALPHA:
		seen[q] = 1
		stack.append(q)


## 상자 테두리(1px 고리)의 가운데값 색. 기준 그림을 잘라 쓸 때 빈 칸 배경 색으로 본다
static func border_median_color(image: Image, rect: Rect2i) -> Color:
	var lumas: Array[Dictionary] = []
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in [rect.position.y, rect.end.y - 1]:
			var c: Color = image.get_pixel(x, y)
			lumas.append({l = c.get_luminance(), c = c})
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in [rect.position.x, rect.end.x - 1]:
			var c: Color = image.get_pixel(x, y)
			lumas.append({l = c.get_luminance(), c = c})
	lumas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.l < b.l)
	return lumas[lumas.size() / 2].c
