extends SceneTree
## 메인 씬을 창 모드로 실행해서 정해진 시간 뒤의 화면을 PNG로 저장하고 끝낸다.
##
## 사용 예 (--headless를 붙이면 화면이 그려지지 않으므로 붙이지 않는다):
##   bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --out=<저장할 PNG 경로>
##
## --seconds: 씬을 띄운 뒤 찍기까지 기다릴 시간 (기본 DEFAULT_SECONDS)
## --out:     저장 경로. 절대 경로나 user:// 경로. 없으면 user://screenshots/ 아래에 시각으로 이름을 짓는다.
## --scene:   메인 씬 대신 띄울 씬 (res:// 경로, 예: res://regions/base.tscn)
## --setup:   찍기 전에 화면 상태를 만들 스크립트 (res:// 경로). static func run(scene: Node) -> void 를 가진다.
##            씬이 준비된 직후 한 번 불린다. 예: tools/screenshot_setups/
## --game_only: 창 그림 대신 3D 게임 화면(GameScreen, 내부 해상도 640×360, HUD·창과 몸 곁 도넛·안내 글자 없음)만 저장한다.
##            3D 층이 없는 씬(--view_2d, 3D를 끈 지역)에서는 찍지 않고 종료 코드 2로 끝낸다.
## 기본으로 저장되는 이미지는 창 그림이다: HUD·창(UI)까지 들고, 크기는 창 크기(기본 1280×720)다.
## (루트 창은 UI를 실제 해상도로, 3D 화면은 640×360을 정수 배율로 늘려 그린다. docs/art-direction.md의 "화면 설정")

const DEFAULT_SECONDS: float = 2.0
const DEFAULT_DIR: String = "user://screenshots"
const GAME_ONLY_ARG: String = "--game_only"

var _seconds: float = DEFAULT_SECONDS
var _out_path: String = ""
var _elapsed: float = 0.0
var _taken: bool = false
var _setup_path: String = ""
var _scene_path: String = ""
var _setup_done: bool = false
var _game_only: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = arg.trim_prefix("--seconds=").to_float()
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--setup="):
			_setup_path = arg.trim_prefix("--setup=")
		elif arg == GAME_ONLY_ARG:
			_game_only = true
	if _out_path.is_empty():
		DirAccess.make_dir_recursive_absolute(DEFAULT_DIR)
		_out_path = DEFAULT_DIR.path_join("screenshot_%s.png" % Time.get_datetime_string_from_system().replace(":", "-"))

	var main_scene: String = _scene_path if not _scene_path.is_empty() else ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene.is_empty():
		printerr("메인 씬이 지정되어 있지 않습니다 (application/run/main_scene).")
		quit(2)
		return
	print("메인 씬: %s, %.1f초 뒤 촬영" % [main_scene, _seconds])
	change_scene_to_file(main_scene)


func _process(delta: float) -> bool:
	if not _setup_done and current_scene != null:
		_setup_done = true
		if not _setup_path.is_empty():
			print("준비 스크립트: %s" % _setup_path)
			load(_setup_path).run(current_scene)
	if _taken:
		return false
	_elapsed += delta
	if _elapsed < _seconds:
		return false
	_taken = true
	# 이번 프레임이 다 그려진 뒤에 찍는다.
	RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)
	return false


func _capture() -> void:
	var image: Image = root.get_texture().get_image()
	if _game_only:
		var view: RegionView3D = current_scene.call(&"get_view_3d") as RegionView3D if current_scene.has_method(&"get_view_3d") else null
		if view == null:
			printerr("%s: 이 씬에는 3D 층(GameScreen)이 없어 게임 화면만 찍을 수 없습니다 (--view_2d나 3D를 끈 지역)." % GAME_ONLY_ARG)
			quit(2)
			return
		image = view.get_screen_texture().get_image()
	var error: Error = image.save_png(_out_path)
	if error != OK:
		printerr("저장 실패 (%s): %s" % [error_string(error), _out_path])
		quit(1)
		return
	print("저장: %s (%d×%d), 현재 씬: %s" % [ProjectSettings.globalize_path(_out_path), image.get_width(), image.get_height(), current_scene.scene_file_path])
	quit(0)
