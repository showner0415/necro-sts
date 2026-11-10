extends SceneTree
## 두 PNG를 픽셀 단위로 비교해서 달라진 픽셀 수·범위·앞쪽 몇 자리를 출력한다. 전후 스크린샷 비교에 쓴다.
## bash tools/godot.sh --headless --path . -s tools/compare_images.gd -- <a.png> <b.png>
## 종료 코드: 같으면 0, 다르면 1, 읽지 못하면 2

const MAX_LISTED: int = 12


func _initialize() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.size() != 2:
		printerr("PNG 경로 두 개가 필요합니다")
		quit(2)
		return
	var a: Image = Image.load_from_file(paths[0])
	var b: Image = Image.load_from_file(paths[1])
	if a == null or b == null or a.get_size() != b.get_size():
		printerr("읽지 못했거나 크기가 다릅니다")
		quit(2)
		return
	var changed: Array[Vector2i] = ImageDiff.changed_pixels(a, b)
	if changed.is_empty():
		print("같음 (%d×%d)" % [a.get_width(), a.get_height()])
		quit(0)
		return
	print("다른 픽셀 %d개, 범위 %s" % [changed.size(), ImageDiff.bounds(changed)])
	for i: int in mini(changed.size(), MAX_LISTED):
		print("  %s: %s → %s" % [changed[i], a.get_pixelv(changed[i]).to_html(false), b.get_pixelv(changed[i]).to_html(false)])
	quit(1)
