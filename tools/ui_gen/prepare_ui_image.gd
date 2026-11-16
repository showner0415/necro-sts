extends SceneTree
## UI 그림 다듬기: 스크립트로 다시 할 수 있는 처리만 한다 (자르기, 투명 테두리 자르기, 크기 맞추기, 나누기, 9-slice 늘려 보기).
## 픽셀을 손으로 고치지 않는다. ui-designer 에이전트(.claude/agents/ui-designer.md "붙이기" 5)와 비교판 만들기에 쓴다.
##
## 실행 (저장소 폴더에서):
##   bash tools/godot.sh --headless --path . -s tools/ui_gen/prepare_ui_image.gd -- --in=<a.png> <처리>... --out=<b.png>
## 처리는 적은 순서대로 한다. --out은 여러 번 줄 수 있다 (그때까지의 결과를 저장).
##   --crop=x,y,w,h            상자만 남긴다
##   --trim[=여백px]           알파가 TRIM_ALPHA 이상인 픽셀을 담는 상자로 자르고, 여백만큼 투명을 둘러 준다
##   --scale=<배율>            배율로 늘리거나 줄인다 (Lanczos)
##   --fit=WxH                 비율을 지키며 W×H 안에 들게 줄이거나 늘린다
##   --canvas=WxH              W×H 투명 판 가운데에 둔다 (크면 먼저 --fit)
##   --bg=<hex>                단색 판 위에 알파로 겹친다 (비교판에서 칸 배경 흉내)
##   --scale-nearest=<정수>    정수 배율로 픽셀 그대로 늘린다 (도트 게임 스크린샷을 1920×1080으로)
##   --nine=WxH:l,t,r,b[:mode[:nocenter]] 9-slice로 W×H 창을 만들어 본다. l,t,r,b는 지금 그림의 픽셀 여백.
##                             mode: stretch(변을 늘림, 기본) / tile(변을 정수 번 반복하되 딱 맞게 조금 늘림).
##                             nocenter면 가운데를 그리지 않는다 (NinePatchRect draw_center = false, 판은 테마가 그림)
##   --under=<hex>:<안쪽px>    가장자리에서 안쪽px 들어간 사각형을 그 색으로 칠하고 그 위에 지금 그림을 겹친다 (테마가 그리는 창 판 흉내)
##   --over=<png>@x,y          다른 PNG를 지금 그림의 (x, y)에 알파로 겹친다 (게임 화면 위에 창 얹어 보기)
##   --split=<접두>            불투명 조각마다(ui_image_lib.components) 잘라 <접두>_<번호>.png로 저장한다 (위 줄부터 왼쪽부터). 끝 처리다
## 예: 아이콘 묶음 나누기  -- --in=icon_set_1.png --split=out/icon_set_1
##     칸 흉내 비교 사본    -- --in=icon.png --trim --fit=72x72 --canvas=96x96 --bg=181425 --out=slot.png
## 종료 코드: 0 = 저장함, 2 = 인자 오류·읽기 실패

const Lib: GDScript = preload("res://tools/ui_gen/ui_image_lib.gd")

## --trim이 남길 최소 알파 (0~255). 부드러운 가장자리를 남기려고 낮게 둔다
const TRIM_ALPHA: int = 8


func _initialize() -> void:
	var image: Image = null
	for arg: String in OS.get_cmdline_user_args():
		var key: String = arg.get_slice("=", 0)
		var value: String = arg.substr(key.length() + 1)
		if key != "--in" and image == null:
			printerr("--in이 먼저 와야 한다")
			quit(2)
			return
		match key:
			"--in":
				image = Lib.load_rgba(value)
				if image == null:
					printerr("읽지 못함: %s" % value)
					quit(2)
					return
			"--crop":
				var n: PackedStringArray = value.split(",")
				image = image.get_region(Rect2i(n[0].to_int(), n[1].to_int(), n[2].to_int(), n[3].to_int()))
			"--trim":
				image = _trim(image, value.to_int())
			"--scale":
				var f: float = value.to_float()
				image.resize(maxi(1, roundi(image.get_width() * f)), maxi(1, roundi(image.get_height() * f)), Image.INTERPOLATE_LANCZOS)
			"--scale-nearest":
				var n: int = value.to_int()
				image.resize(image.get_width() * n, image.get_height() * n, Image.INTERPOLATE_NEAREST)
			"--under":
				image = _under(image, Color.from_string(value.get_slice(":", 0), Color.WHITE), value.get_slice(":", 1).to_int())
			"--over":
				var top: Image = Lib.load_rgba(value.get_slice("@", 0))
				if top == null:
					printerr("읽지 못함: %s" % value)
					quit(2)
					return
				var at: PackedStringArray = value.get_slice("@", 1).split(",")
				image.blend_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i(at[0].to_int(), at[1].to_int()))
			"--fit":
				image = _fit(image, _size(value))
			"--canvas":
				image = _canvas(image, _size(value))
			"--bg":
				image = _on_color(image, Color.from_string(value, Color.WHITE))
			"--nine":
				var parts: PackedStringArray = value.split(":")
				var m: PackedStringArray = parts[1].split(",")
				var mode: String = parts[2] if parts.size() > 2 else "stretch"
				var draw_center: bool = not (parts.size() > 3 and parts[3] == "nocenter")
				image = _nine(image, _size(parts[0]), Vector4i(m[0].to_int(), m[1].to_int(), m[2].to_int(), m[3].to_int()), mode, draw_center)
			"--out":
				var error: int = image.save_png(value)
				print("저장: %s (%s), %d×%d" % [value, error_string(error), image.get_width(), image.get_height()])
				if error != OK:
					quit(2)
					return
			"--split":
				var boxes: Array[Rect2i] = Lib.components(image)
				for i: int in boxes.size():
					var piece: Image = _trim(image.get_region(boxes[i]), 0)
					var path: String = "%s_%d.png" % [value, i + 1]
					var error: int = piece.save_png(path)
					print("저장: %s (%s), %d×%d, 원본 상자 %s" % [path, error_string(error), piece.get_width(), piece.get_height(), boxes[i]])
				quit(0)
				return
			_:
				printerr("모르는 처리: %s" % arg)
				quit(2)
				return
	quit(0)


func _size(text: String) -> Vector2i:
	return Vector2i(text.get_slice("x", 0).to_int(), text.get_slice("x", 1).to_int())


func _trim(image: Image, pad: int) -> Image:
	var box: Rect2i = Lib.alpha_bbox(image, TRIM_ALPHA)
	if not box.has_area():
		return image
	var cut: Image = image.get_region(box)
	if pad <= 0:
		return cut
	var out: Image = Image.create_empty(cut.get_width() + pad * 2, cut.get_height() + pad * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(cut, Rect2i(Vector2i.ZERO, cut.get_size()), Vector2i(pad, pad))
	return out


func _fit(image: Image, box: Vector2i) -> Image:
	var f: float = minf(float(box.x) / image.get_width(), float(box.y) / image.get_height())
	var out: Image = image.duplicate()
	out.resize(maxi(1, roundi(image.get_width() * f)), maxi(1, roundi(image.get_height() * f)), Image.INTERPOLATE_LANCZOS)
	return out


func _canvas(image: Image, size: Vector2i) -> Image:
	if image.get_width() > size.x or image.get_height() > size.y:
		image = _fit(image, size)
	var out: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), (size - image.get_size()) / 2)
	return out


func _on_color(image: Image, color: Color) -> Image:
	var out: Image = Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(color, 1.0))
	out.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return out


## 9-slice: 네 모서리는 그대로, 변은 늘리거나 반복, 가운데는 늘린다. margins는 (왼, 위, 오, 아래)
func _nine(image: Image, size: Vector2i, margins: Vector4i, mode: String, draw_center: bool) -> Image:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var l: int = margins.x
	var t: int = margins.y
	var r: int = margins.z
	var b: int = margins.w
	var src_mid: Vector2i = Vector2i(w - l - r, h - t - b)
	var dst_mid: Vector2i = Vector2i(size.x - l - r, size.y - t - b)
	var out: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	# 모서리
	out.blit_rect(image, Rect2i(0, 0, l, t), Vector2i(0, 0))
	out.blit_rect(image, Rect2i(w - r, 0, r, t), Vector2i(size.x - r, 0))
	out.blit_rect(image, Rect2i(0, h - b, l, b), Vector2i(0, size.y - b))
	out.blit_rect(image, Rect2i(w - r, h - b, r, b), Vector2i(size.x - r, size.y - b))
	# 변
	_blit_strip(out, image.get_region(Rect2i(l, 0, src_mid.x, t)), Vector2i(l, 0), Vector2i(dst_mid.x, t), true, mode)
	_blit_strip(out, image.get_region(Rect2i(l, h - b, src_mid.x, b)), Vector2i(l, size.y - b), Vector2i(dst_mid.x, b), true, mode)
	_blit_strip(out, image.get_region(Rect2i(0, t, l, src_mid.y)), Vector2i(0, t), Vector2i(l, dst_mid.y), false, mode)
	_blit_strip(out, image.get_region(Rect2i(w - r, t, r, src_mid.y)), Vector2i(size.x - r, t), Vector2i(r, dst_mid.y), false, mode)
	# 가운데
	if not draw_center:
		return out
	var center: Image = image.get_region(Rect2i(l, t, src_mid.x, src_mid.y))
	center.resize(maxi(1, dst_mid.x), maxi(1, dst_mid.y), Image.INTERPOLATE_BILINEAR)
	out.blit_rect(center, Rect2i(Vector2i.ZERO, center.get_size()), Vector2i(l, t))
	return out


## 안쪽 사각형을 색으로 칠한 판 위에 그림을 겹친다
func _under(image: Image, color: Color, inset: int) -> Image:
	var out: Image = Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	out.fill_rect(Rect2i(inset, inset, image.get_width() - inset * 2, image.get_height() - inset * 2), Color(color, 1.0))
	out.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return out


func _blit_strip(out: Image, strip: Image, at: Vector2i, size: Vector2i, horizontal: bool, mode: String) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	if mode != "tile":
		strip.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(strip, Rect2i(Vector2i.ZERO, size), at)
		return
	var src_len: int = strip.get_width() if horizontal else strip.get_height()
	var dst_len: int = size.x if horizontal else size.y
	var count: int = maxi(1, roundi(float(dst_len) / src_len))
	var offset: int = 0
	for i: int in count:
		# 마지막 조각이 남는 길이를 모두 가진다 (반올림 오차)
		var piece_len: int = dst_len / count if i < count - 1 else dst_len - offset
		var piece: Image = strip.duplicate()
		if horizontal:
			piece.resize(piece_len, size.y, Image.INTERPOLATE_LANCZOS)
			out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), at + Vector2i(offset, 0))
		else:
			piece.resize(size.x, piece_len, Image.INTERPOLATE_LANCZOS)
			out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), at + Vector2i(0, offset))
		offset += piece_len
