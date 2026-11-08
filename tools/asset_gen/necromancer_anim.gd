extends SceneTree
## 네크로맨서 애니메이션을 PixelLab 원본 ZIP에서 꺼내 게임에 넣는다.
## - ZIP 안 metadata.json의 frames.animations.Walking.<방향> 목록대로 프레임 PNG를 꺼내
##   assets/necromancer/anim/walk/<방향>/frame_000.png … 로 그대로 저장한다 (자르거나 늘리지 않는다. 방향 이름의 하이픈은 밑줄로)
## - 그 프레임과 8방향 정지 그림(assets/necromancer/necromancer_<방향>.png)으로 SpriteFrames를 만든다:
##   애니메이션 idle_<방향>(정지 그림 한 장)과 walk_<방향>(걷기 프레임, WALK_FPS, 반복)
## - ZIP의 정지 그림(frames.rotations)이 assets의 정지 그림과 다르면 알려 준다 (정지 그림은 바꾸지 않는다)
## - 프레임 크기가 방향마다 다르면 멈춘다. 정지 그림(32×32, 발 y=28)과 같은 자리에 서게 할 걷기 기준점을 출력한다
##   (걷기 프레임은 정지 그림 캔버스에 사방 같은 여백을 붙인 것으로 본다)
## ZIP을 새로 받으면 이 스크립트만 다시 돌린다. SpriteFrames(.tres)는 손으로 고치지 않는다.
##
## 실행:
##   bash tools/godot.sh --headless --path . -s tools/asset_gen/necromancer_anim.gd
##   bash tools/godot.sh --headless --path . --import   (새 PNG를 임포트한다. tests/run_all.sh도 처음에 한다)
## 다른 ZIP: -- --zip=res://art_src/necromancer/<파일>.zip

const DEFAULT_ZIP: String = "res://art_src/necromancer/Create_a_high-quality_si-pallete.zip"
const WALK_DIR: String = "res://assets/necromancer/anim/walk"
const FRAMES_PATH: String = "res://assets/necromancer/anim/necromancer_frames.tres"
const STILL_PATH: String = "res://assets/necromancer/necromancer_%s.png"
## ZIP 안의 걷기 애니메이션 이름 (metadata.json)
const WALK_ANIMATION: String = "Walking"
## 방향 이름: Facing 규칙의 번호 순서 (동쪽부터 화면 시계 방향). ZIP에서는 하이픈으로 쓴다
const DIRECTIONS: Array[String] = ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
## 걷기 재생 속도 (초당 프레임, 임시값). 게임에서는 이동 속도에 맞춰 FacingSprite가 배율을 곱한다
const WALK_FPS: float = 12.0
## 정지 그림의 크기와 발 위치 (assets/ASSETS.md)
const STILL_SIZE: Vector2i = Vector2i(32, 32)
const STILL_FOOT_Y: int = 28


func _initialize() -> void:
	var zip_path: String = DEFAULT_ZIP
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--zip="):
			zip_path = arg.trim_prefix("--zip=")
	var zip: ZIPReader = ZIPReader.new()
	if zip.open(ProjectSettings.globalize_path(zip_path)) != OK:
		_fail("ZIP을 열 수 없음: %s" % zip_path)
		return
	var metadata: Variant = JSON.parse_string(zip.read_file(_find(zip, "metadata.json")).get_string_from_utf8())
	if not metadata is Dictionary or (metadata as Dictionary).get("states", []).is_empty():
		_fail("metadata.json에 states가 없음")
		return
	var frames_info: Dictionary = metadata.states[0].frames
	var walking: Dictionary = frames_info.get("animations", {}).get(WALK_ANIMATION, {})
	var frame_size: Vector2i = Vector2i.ZERO
	var walk_paths: Dictionary = {}
	for direction: String in DIRECTIONS:
		var files: Array = walking.get(direction.replace("_", "-"), [])
		if files.is_empty():
			_fail("걷기 프레임이 없는 방향: %s" % direction)
			return
		var out_dir: String = "%s/%s" % [WALK_DIR, direction]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var written: Array[String] = []
		for i: int in files.size():
			var image: Image = Image.new()
			if image.load_png_from_buffer(zip.read_file(files[i])) != OK:
				_fail("PNG를 읽을 수 없음: %s" % files[i])
				return
			if frame_size == Vector2i.ZERO:
				frame_size = image.get_size()
			elif image.get_size() != frame_size:
				_fail("프레임 크기가 다름: %s는 %s (앞의 프레임은 %s)" % [files[i], image.get_size(), frame_size])
				return
			var path: String = "%s/frame_%03d.png" % [out_dir, i]
			image.save_png(ProjectSettings.globalize_path(path))
			written.append(path.get_file())
		_remove_stale(out_dir, written)
		walk_paths[direction] = written.map(func(file: String) -> String: return "%s/%s" % [out_dir, file])
		print("걷기 %s: %d프레임" % [direction, files.size()])
	_compare_stills(zip, frames_info.get("rotations", {}))
	zip.close()
	_write_frames(walk_paths)
	var margin: Vector2i = (frame_size - STILL_SIZE) / 2
	print("프레임 크기 %s, 정지 그림 %s → 걷기 기준점(발밑) offset %s (FacingSprite.walk_offset과 같아야 함)" % [
		frame_size, STILL_SIZE, -Vector2(STILL_SIZE.x / 2 + margin.x, STILL_FOOT_Y + margin.y)])
	print("저장: %s. 이제 --import로 새 PNG를 임포트한다" % FRAMES_PATH)
	quit()


## ZIP 안에서 이름이 file_name으로 끝나는 첫 파일
func _find(zip: ZIPReader, file_name: String) -> String:
	for file: String in zip.get_files():
		if file.get_file() == file_name:
			return file
	return file_name


## out_dir의 frame_*.png 중 이번에 쓰지 않은 것(ZIP의 프레임 수가 줄었을 때)과 그 .import를 지운다.
func _remove_stale(out_dir: String, written: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(out_dir)
	for file: String in dir.get_files():
		var png: String = file.trim_suffix(".import")
		if png.begins_with("frame_") and png.ends_with(".png") and not written.has(png):
			dir.remove(file)
			print("지움: %s/%s" % [out_dir, file])


func _compare_stills(zip: ZIPReader, rotations: Dictionary) -> void:
	for direction: String in DIRECTIONS:
		var file: String = rotations.get(direction.replace("_", "-"), "")
		if file.is_empty():
			continue
		var from_zip: Image = Image.new()
		from_zip.load_png_from_buffer(zip.read_file(file))
		var still: Image = Image.load_from_file(ProjectSettings.globalize_path(STILL_PATH % direction))
		if still == null or still.get_size() != from_zip.get_size() or still.get_data() != _same_format(from_zip, still).get_data():
			print("알림: ZIP의 정지 그림 %s가 %s와 다름 (정지 그림은 바꾸지 않았다)" % [file, STILL_PATH % direction])


func _same_format(image: Image, like: Image) -> Image:
	if image.get_format() != like.get_format():
		image.convert(like.get_format())
	return image


## SpriteFrames를 글로 써 낸다 (ext_resource에 uid를 적지 않는다. 임포트할 때 Godot가 채운다).
func _write_frames(walk_paths: Dictionary) -> void:
	var ext: PackedStringArray = []
	var animations: PackedStringArray = []
	for direction: String in DIRECTIONS:
		ext.append('[ext_resource type="Texture2D" path="%s" id="%d"]' % [STILL_PATH % direction, ext.size() + 1])
		animations.append(_animation("idle_" + direction, [ext.size()], 1.0, false))
	for direction: String in DIRECTIONS:
		var ids: Array[int] = []
		for path: String in walk_paths[direction]:
			ext.append('[ext_resource type="Texture2D" path="%s" id="%d"]' % [path, ext.size() + 1])
			ids.append(ext.size())
		animations.append(_animation("walk_" + direction, ids, WALK_FPS, true))
	var text: String = '[gd_resource type="SpriteFrames" format=3]\n\n%s\n\n[resource]\nanimations = [%s]\n' % ["\n".join(ext), ", ".join(animations)]
	var file: FileAccess = FileAccess.open(FRAMES_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _animation(anim_name: String, ids: Array, fps: float, loop: bool) -> String:
	var frames: PackedStringArray = []
	for id: int in ids:
		frames.append('{\n"duration": 1.0,\n"texture": ExtResource("%d")\n}' % id)
	return '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % [", ".join(frames), "true" if loop else "false", anim_name, fps]


func _fail(message: String) -> void:
	printerr("문제: ", message)
	quit(1)
