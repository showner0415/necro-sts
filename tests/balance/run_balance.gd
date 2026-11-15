extends ScenarioTest
## 밸런스 측정: 플레이어 봇(PlayerBot)이 시험 지역에서 몬스터와 싸운 결과를 잰다.
## 대상 × 조건(혼자 / 쥐 언데드 2마리와 함께) × 실력 단계마다 runs번 싸워서
## 잡는 시간과 받은 피해의 평균·가장 나쁜 경우, 죽은 비율, 시간 초과 비율, 명중률을 표로 출력한다.
## 언데드와 함께인 줄에는 "언데드 효과"(같은 대상·실력의 혼자 줄 대비 잡는 시간·받은 피해·사망률 변화)를 붙인다.
## 2등급은 시간보다 피해와 사망률이 언데드로 크게 줄어드는지가 기준이다 (docs/game-design.md 등급).
## 판정(통과/실패)을 내지 않으므로 run_all.sh에는 넣지 않는다. 몬스터를 추가하면 TARGETS에 넣고 다시 잰다.
##
## 전부 측정 (헤드리스, 빠르게):
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_balance.gd
## 일부만: -- --targets=boar,bat_pack --skills=normal --undead=0 --runs=5
## 쥐 패거리 (기본 대상에 없음, 계획 8b-2): -- --targets=rat_gang3,rat_gang3_leader,rat_gang4,rat_gang4_leader (결과 tests/balance/results/2026-11-15_rat_pack_fight.md)
## 벽 방의 쥐 (계획 8b-5): -- --targets=rat_room_s,rat_gang4_room_s,rat_gang4_leader_room_s,rat_room_l,rat_gang4_room_l,rat_gang4_leader_room_l (_s 작은 방 12×9칸, _l 입구 굴만 한 방 36×31칸)
## 멧돼지·투석병·섞인 무리 (봇 측정 1단계): -- --targets=boar_pack2,boar_pack2_leader,boar_pack3,boar_pack3_leader,goblin_pack2,goblin_pack2_leader,goblin_pack3,goblin_pack3_leader,mixed3,mixed3_leader,mixed4,mixed4_leader
## 쥐 큰 무리 (봇 측정 3단계): -- --targets=rat_big6,rat_big6_leader,rat_big8,rat_big8_leader
## 추가 공격권 간격 바꿔 재기 (봇 측정 4a, 측정 안에서만): -- --targets=boar_pack2 --rooms=s --timeout=120 --extra_interval=2.0 (멧돼지 무리는 120초로 잰다) (결과 tests/balance/results/2026-11-15_token_extra_interval.md)
## 공격권 시간 제한·막기·맴도는 거리 바꿔 재기 (봇 측정 4b, 측정 안에서만): -- --targets=boar_pack2 --rooms=s --timeout=120 --hold_time_limit=8 (또는 --retry_block_time=2, --wait_distance=128. 결과 tests/balance/results/2026-11-15_token_hold_block_wait.md)
## 벽 방 판 (봇 측정 3단계): -- --targets=boar_pack2,rat_big6 --rooms=s,l (대상마다 작은 방 _room_s·큰 방 _room_l 판으로 바꾼다. 결과 tests/balance/results/2026-11-15_pack_room.md)
##   3a 측정 전부 (무리 열여섯 × 두 방, 결과 tests/balance/results/2026-11-15_pack_room.md): -- --targets=boar_pack2,boar_pack2_leader,boar_pack3,boar_pack3_leader,goblin_pack2,goblin_pack2_leader,goblin_pack3,goblin_pack3_leader,mixed3,mixed3_leader,mixed4,mixed4_leader,rat_big6,rat_big6_leader,rat_big8,rat_big8_leader --rooms=s,l
## 판마다 시드(BASE_SEED + 판 번호)로 던전 상태와 지역 공격권의 난수도 맞추므로, 같은 대상·판 번호면 다른 대상·실력과 함께 돌려도 결과가 같다 (봇 측정 1단계)
## 봇이 몬스터와 유지하는 거리 바꾸기: -- --keep=0 (0이면 거리를 두지 않고 제자리에서 쏘며 예고만 피한다)
## 봇이 쏘기를 멈추고 뛰는 거리 바꾸기: -- --run_distance=20 (기본 55. keep이 이보다 작으면 다가오는 몬스터마다 뛰어서 싸움이 끝나지 않을 수 있다)
## 무리 동시 공격(박쥐 동시 돌진)을 처음 N번 일부러 못 피하게: -- --miss_pack=1
##   놓친 동시 공격에서 받은 피해, 그 직후 마나, 언데드가 죽거나 해제된 수, 죽은 비율로 "실수 한 번의 값"을 본다
## 봇이 싸우는 모습을 창으로 보기 (실제 속도, 한 판):
##   bash tools/godot.sh --path . -s tests/balance/run_balance.gd -- --targets=boar --skills=normal --undead=0 --runs=1
##
## 싸움터: 시험 지역에서 몬스터와 탈출 지점을 모두 치우고, 네크로맨서는 가운데, 대상은 SPAWN_OFFSET에 둔다
## (감지 범위 밖이라 봇이 먼저 쏴서 싸움을 건다). 판마다 난수 시드를 바꾼다.

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const UNDEAD_BONES: int = 40
## 대상 id → [몬스터 데이터, 놓을 자리들 (SPAWN_OFFSET 기준)]
const TARGETS: Dictionary = {
	&"rat": {"name": "쥐 1마리", "data": "res://data/monsters/rat.tres", "offsets": [Vector2.ZERO]},
	&"boar": {"name": "멧돼지 1마리", "data": "res://data/monsters/boar.tres", "offsets": [Vector2.ZERO]},
	&"bat_pack": {"name": "박쥐 무리(3)", "data": "res://data/monsters/bat.tres", "offsets": [Vector2(0, -12), Vector2(12, 0), Vector2(0, 12)], "pack": true},
	&"goblin_pair": {"name": "고블린 투석병(2)", "data": "res://data/monsters/goblin_slinger.tres", "offsets": [Vector2(0, -25), Vector2(10, 25)]},
	## 벽으로 둘러싸인 방 (12×9칸, 얕은 굴의 작은 굴 64~115칸과 비슷하다). 기본 대상에는 넣지 않는다: --targets=goblin_room
	&"goblin_room": {"name": "고블린 투석병(2), 벽 방", "data": "res://data/monsters/goblin_slinger.tres", "offsets": [Vector2(0, -25), Vector2(10, 25)],
		"room": Vector2(384, 288), "start": Vector2(-120, 0), "spawn": Vector2(110, 0)},
	## 쥐 패거리 (계획 8b-2): 무리 자리처럼 MonsterPack으로 묶어 경보·함께 배회·공격권이 붙는다. 무리원 사이는 무리 자리의 min_spacing(16)과 같게.
	## "leader"면 첫 무리원이 대장이다 (PackSpawn과 같게 체력 × leader_health_ratio, 무리원 공격력 × member_damage_ratio). 기본 대상에는 넣지 않는다
	&"rat_gang3": {"name": "쥐 패거리(3)", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16)], "pack": true},
	&"rat_gang3_leader": {"name": "쥐 패거리(3), 대장", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16)], "pack": true, "leader": true},
	&"rat_gang4": {"name": "쥐 패거리(4)", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)], "pack": true},
	&"rat_gang4_leader": {"name": "쥐 패거리(4), 대장", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)], "pack": true, "leader": true},
	## 벽 방의 쥐 (계획 8b-5, 사용자 결정 2026-11-15: 두 크기를 재서 비교). 시작·몬스터 자리는 두 방 모두 goblin_room과 같다 (방 크기만 다르게).
	## "arena"는 봇이 방 가운데로 돌아오기 시작하는 거리 = 방 짧은 변의 절반 - 24 (goblin_room의 120과 같은 규칙). 기본 대상에는 넣지 않는다
	## _s: 작은 방 12×9칸 (goblin_room 크기). _l: 입구 굴만 한 방 36×31칸 (입구 굴 바닥 1129칸과 넓이가 비슷하고 테두리 42×36칸과 비율이 비슷, 바위 없음)
	&"rat_room_s": {"name": "쥐 1마리, 작은 방", "data": "res://data/monsters/rat.tres", "offsets": [Vector2.ZERO],
		"room": Vector2(384, 288), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 120.0},
	&"rat_gang4_room_s": {"name": "쥐 패거리(4), 작은 방", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)], "pack": true,
		"room": Vector2(384, 288), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 120.0},
	&"rat_gang4_leader_room_s": {"name": "쥐 패거리(4), 대장, 작은 방", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)], "pack": true, "leader": true,
		"room": Vector2(384, 288), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 120.0},
	&"rat_room_l": {"name": "쥐 1마리, 큰 방", "data": "res://data/monsters/rat.tres", "offsets": [Vector2.ZERO],
		"room": Vector2(1152, 992), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 472.0},
	&"rat_gang4_room_l": {"name": "쥐 패거리(4), 큰 방", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)], "pack": true,
		"room": Vector2(1152, 992), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 472.0},
	&"rat_gang4_leader_room_l": {"name": "쥐 패거리(4), 대장, 큰 방", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)], "pack": true, "leader": true,
		"room": Vector2(1152, 992), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 472.0},
	## 멧돼지·투석병·섞인 무리 (봇 측정 계획 1단계, 사용자 결정 2026-11-15: 크기마다 대상 + 대장 판). 크기는 data/packs/*.tres의 범위 끝 둘.
	## 몸이 쥐보다 커서 무리원 사이를 24px로 둔다. 대장은 첫 무리원이고, "leader_index"가 있으면 그 차례의 무리원이다.
	## 섞인 무리의 대장은 첫 쥐다 (봇 측정 3단계, 사용자 결정 2026-11-15: 쥐만 대장. 실제 무리 자리는 무리원 중 아무나). 기본 대상에는 넣지 않는다
	&"boar_pack2": {"name": "멧돼지 무리(2)", "data": "res://data/monsters/boar.tres", "offsets": [Vector2(0, -12), Vector2(0, 12)], "pack": true},
	&"boar_pack2_leader": {"name": "멧돼지 무리(2), 대장", "data": "res://data/monsters/boar.tres", "offsets": [Vector2(0, -12), Vector2(0, 12)], "pack": true, "leader": true},
	&"boar_pack3": {"name": "멧돼지 무리(3)", "data": "res://data/monsters/boar.tres", "offsets": [Vector2(0, -24), Vector2(0, 0), Vector2(0, 24)], "pack": true},
	&"boar_pack3_leader": {"name": "멧돼지 무리(3), 대장", "data": "res://data/monsters/boar.tres", "offsets": [Vector2(0, -24), Vector2(0, 0), Vector2(0, 24)], "pack": true, "leader": true},
	&"goblin_pack2": {"name": "투석병 무리(2)", "data": "res://data/monsters/goblin_slinger.tres", "offsets": [Vector2(0, -12), Vector2(0, 12)], "pack": true},
	&"goblin_pack2_leader": {"name": "투석병 무리(2), 대장", "data": "res://data/monsters/goblin_slinger.tres", "offsets": [Vector2(0, -12), Vector2(0, 12)], "pack": true, "leader": true},
	&"goblin_pack3": {"name": "투석병 무리(3)", "data": "res://data/monsters/goblin_slinger.tres", "offsets": [Vector2(0, -24), Vector2(0, 0), Vector2(0, 24)], "pack": true},
	&"goblin_pack3_leader": {"name": "투석병 무리(3), 대장", "data": "res://data/monsters/goblin_slinger.tres", "offsets": [Vector2(0, -24), Vector2(0, 0), Vector2(0, 24)], "pack": true, "leader": true},
	&"mixed3": {"name": "섞인 무리(멧돼지 1 + 쥐 2)", "data": "res://data/monsters/boar.tres", "datas": ["res://data/monsters/boar.tres", "res://data/monsters/rat.tres", "res://data/monsters/rat.tres"],
		"offsets": [Vector2(0, 0), Vector2(24, -16), Vector2(24, 16)], "pack": true},
	&"mixed3_leader": {"name": "섞인 무리(멧돼지 1 + 쥐 2), 대장", "data": "res://data/monsters/boar.tres", "datas": ["res://data/monsters/boar.tres", "res://data/monsters/rat.tres", "res://data/monsters/rat.tres"],
		"offsets": [Vector2(0, 0), Vector2(24, -16), Vector2(24, 16)], "pack": true, "leader": true, "leader_index": 1},
	&"mixed4": {"name": "섞인 무리(멧돼지 1 + 쥐 3)", "data": "res://data/monsters/boar.tres", "datas": ["res://data/monsters/boar.tres", "res://data/monsters/rat.tres", "res://data/monsters/rat.tres", "res://data/monsters/rat.tres"],
		"offsets": [Vector2(0, 0), Vector2(24, -16), Vector2(24, 16), Vector2(40, 0)], "pack": true},
	&"mixed4_leader": {"name": "섞인 무리(멧돼지 1 + 쥐 3), 대장", "data": "res://data/monsters/boar.tres", "datas": ["res://data/monsters/boar.tres", "res://data/monsters/rat.tres", "res://data/monsters/rat.tres", "res://data/monsters/rat.tres"],
		"offsets": [Vector2(0, 0), Vector2(24, -16), Vector2(24, 16), Vector2(40, 0)], "pack": true, "leader": true, "leader_index": 1},
	## 쥐 큰 무리 (봇 측정 3단계): 크기는 data/packs/rat_big.tres의 범위 끝 둘(6·8). 무리원 사이는 쥐 패거리 대상과 같은 16px로, 두 줄 격자에 놓는다 (측정 조건). 기본 대상에는 넣지 않는다
	&"rat_big6": {"name": "쥐 큰 무리(6)", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(-16, -8), Vector2(0, -8), Vector2(16, -8), Vector2(-16, 8), Vector2(0, 8), Vector2(16, 8)], "pack": true},
	&"rat_big6_leader": {"name": "쥐 큰 무리(6), 대장", "data": "res://data/monsters/rat.tres", "offsets": [Vector2(-16, -8), Vector2(0, -8), Vector2(16, -8), Vector2(-16, 8), Vector2(0, 8), Vector2(16, 8)], "pack": true, "leader": true},
	&"rat_big8": {"name": "쥐 큰 무리(8)", "data": "res://data/monsters/rat.tres",
		"offsets": [Vector2(-24, -8), Vector2(-8, -8), Vector2(8, -8), Vector2(24, -8), Vector2(-24, 8), Vector2(-8, 8), Vector2(8, 8), Vector2(24, 8)], "pack": true},
	&"rat_big8_leader": {"name": "쥐 큰 무리(8), 대장", "data": "res://data/monsters/rat.tres",
		"offsets": [Vector2(-24, -8), Vector2(-8, -8), Vector2(8, -8), Vector2(24, -8), Vector2(-24, 8), Vector2(-8, 8), Vector2(8, 8), Vector2(24, 8)], "pack": true, "leader": true},
}
## 벽 방 판 (봇 측정 3단계, 사용자 결정 2026-11-15: 벽 방 두 크기): TARGETS에 없는 "<대상>_room_s"·"<대상>_room_l"은 그 대상에 이 방을 붙여 만든다 (get_target).
## 방 크기·시작·몬스터 자리·arena는 벽 방의 쥐 대상(rat_room_s·rat_room_l)과 같다. TARGETS에 직접 적은 방 대상이 있으면 그것을 쓴다
const ROOMS: Dictionary = {
	"_room_s": {"name": "작은 방", "room": Vector2(384, 288), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 120.0},
	"_room_l": {"name": "큰 방", "room": Vector2(1152, 992), "start": Vector2(-120, 0), "spawn": Vector2(110, 0), "arena": 472.0},
}
## 대장 값 (PackSpawn과 같은 파일)
const LEADER_SETTINGS: String = "res://data/packs/leader_settings.tres"
## 벽 방의 벽 두께 (픽셀), 벽의 충돌층 (지역의 벽과 같다), 봇이 방 가운데로 돌아오기 시작하는 거리 (픽셀)
const ROOM_WALL_THICKNESS: float = 32.0
const ROOM_WALL_LAYER: int = 1
const ROOM_ARENA_RADIUS: float = 120.0
const SPAWN_OFFSET: Vector2 = Vector2(150, 0)
const DEFAULT_RUNS: int = 20
## 한 판의 시간 한계 (초). 넘으면 "시간 초과"로 센다.
const DEFAULT_TIMEOUT: float = 60.0
## 판마다 시드 = BASE_SEED + 판 번호
const BASE_SEED: int = 1000

var _targets: Array[StringName] = [&"rat", &"boar", &"bat_pack", &"goblin_pair"]
var _skills: Array[StringName] = [&"skilled", &"normal", &"novice"]
var _undead_counts: Array[int] = [0, 2]
var _runs: int = DEFAULT_RUNS
var _timeout: float = DEFAULT_TIMEOUT
## 봇이 근접 몬스터와 유지하는 거리. 음수면 봇의 기본값.
var _keep: float = -1.0
## 봇이 쏘기를 멈추고 뛰는 거리. 음수면 봇의 기본값.
var _run_distance: float = -1.0
## 처음 이 횟수만큼의 무리 동시 공격은 봇이 일부러 피하지 않는다
var _miss_pack: int = 0
## 대상마다 붙일 방 (--rooms=s,l → "_room_s", "_room_l"). 비어 있으면 대상 그대로
var _rooms: Array[String] = []
## 0 이상이면 측정 안에서만 추가 공격권 간격(초)을 이 값으로 바꾼다 (--extra_interval=2.0, 봇 측정 4a). 음수면 지역 기본값
var _extra_interval: float = -1.0
## 0 이상이면 측정 안에서만 공격권 시간 제한·시간 제한 뒤 막기(초)를 이 값으로 바꾼다 (--hold_time_limit=8, --retry_block_time=2, 봇 측정 4b). 음수면 지역 기본값
var _hold_time_limit: float = -1.0
var _retry_block_time: float = -1.0
## 0 이상이면 측정 안에서만 놓는 몬스터의 맴도는 거리(token_wait_distance, px)를 이 값으로 바꾼다 (--wait_distance=128, 봇 측정 4b). 음수면 데이터 기본값
var _wait_distance: float = -1.0


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_parse_args()
	_run_all()


func _parse_args() -> void:
	apply_goblin_args()
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		if parts.size() != 2:
			continue
		var values: PackedStringArray = parts[1].split(",")
		match parts[0]:
			"targets":
				_targets.assign(Array(values).map(func(v: String) -> StringName: return StringName(v)))
			"skills":
				_skills.assign(Array(values).map(func(v: String) -> StringName: return StringName(v)))
			"undead":
				_undead_counts.assign(Array(values).map(func(v: String) -> int: return int(v)))
			"runs":
				_runs = int(parts[1])
			"timeout":
				_timeout = float(parts[1])
			"miss_pack":
				_miss_pack = int(parts[1])
			"keep":
				_keep = float(parts[1])
			"run_distance":
				_run_distance = float(parts[1])
			"extra_interval":
				_extra_interval = float(parts[1])
			"hold_time_limit":
				_hold_time_limit = float(parts[1])
			"retry_block_time":
				_retry_block_time = float(parts[1])
			"wait_distance":
				_wait_distance = float(parts[1])
			"rooms":
				_rooms.assign(Array(values).map(func(v: String) -> String: return "_room_" + v))
	# --rooms=s,l: 대상마다 방 판으로 바꾼다 (대상 차례대로, 대상 하나의 방 판이 붙어 나온다)
	if not _rooms.is_empty():
		var expanded: Array[StringName] = []
		for target_id: StringName in _targets:
			for suffix: String in _rooms:
				expanded.append(StringName(String(target_id) + suffix))
		_targets = expanded


## 대상 id의 설정. TARGETS에 없고 "<대상>_room_s"·"<대상>_room_l" 꼴이면 그 대상에 ROOMS의 방을 붙여 만든다.
static func get_target(target_id: StringName) -> Dictionary:
	if TARGETS.has(target_id):
		return TARGETS[target_id]
	for suffix: String in ROOMS:
		var base: StringName = StringName(String(target_id).trim_suffix(suffix))
		if String(target_id).ends_with(suffix) and TARGETS.has(base):
			var target: Dictionary = (TARGETS[base] as Dictionary).duplicate()
			var room: Dictionary = ROOMS[suffix]
			for key: String in room:
				target[key] = room[key]
			target["name"] = "%s, %s" % [TARGETS[base]["name"], room["name"]]
			return target
	return TARGETS[target_id]


func _run_all() -> void:
	var rows: Array[String] = []
	var error_rows: Array[String] = []
	var durability_rows: Array[String] = []
	## [대상, 실력] → 혼자일 때 요약 (언데드 효과의 기준)
	var alone: Dictionary = {}
	for target_id: StringName in _targets:
		for undead_count: int in _undead_counts:
			for skill_id: StringName in _skills:
				var results: Array[Dictionary] = []
				for run: int in _runs:
					var result: Dictionary = await _fight(target_id, undead_count, skill_id, run)
					if not result.has("invalid"):
						results.append(result)
				var stats: Dictionary = _summarize(results)
				if undead_count == 0:
					alone[[target_id, skill_id]] = stats
				var row: String = _summary_row(target_id, undead_count, skill_id, stats, alone.get([target_id, skill_id]))
				print(row)
				rows.append(row)
				error_rows.append(_error_row(target_id, undead_count, skill_id, results))
				if undead_count > 0:
					durability_rows.append(_durability_row(target_id, undead_count, skill_id, results))
	print("")
	print("| 대상 | 조건 | 실력 | 잡은 시간 평균 | 가장 늦게 | 받은 피해 평균 | 가장 많이 | 죽음 | 시간 초과 | 언데드 효과: 시간 | 언데드 효과: 피해 | 언데드 효과: 사망률 | 명중률 | 본 예고(돌 포함) | 구름 | 소환 | 가장 가까이 온 거리 | 동시 공격 | 놓친 동시 공격 피해 | 놓친 직후 마나 | 최저 마나 | 언데드 죽음 | 언데드 해제 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	if _miss_pack > 0:
		print("(무리 동시 공격 처음 %d번은 일부러 피하지 않음)" % _miss_pack)
	for row: String in rows:
		print(row)
	print("")
	print("| 대상 | 조건 | 실력 | 판 | 잡은 시간 (95% 오차) | 받은 피해 (95% 오차) | 죽음 (95% 범위) |")
	print("|---|---|---|---|---|---|---|")
	for row: String in error_rows:
		print(row)
	if not durability_rows.is_empty():
		print("")
		print("| 대상 | 조건 | 실력 | 판 | 머리뼈 내구도 소모 합계 (판당, 95% 오차) | 초당 소모 (합계) |")
		print("|---|---|---|---|---|---|")
		for row: String in durability_rows:
			print(row)
	finish(start_failures == 0)


## 측정 안에서만 이 지역 공격권 값을 인자대로 바꾼다 (--extra_interval·--hold_time_limit·--retry_block_time, 음수면 그대로).
## 보드의 @export는 _ready에서 AttackTokens로 넘어가므로 tokens 쪽을 바꾼다. .tres·기본값은 그대로. 보드가 없으면 건너뛴다
func _apply_token_args() -> void:
	var board: AttackTokenBoard = get_first_node_in_group(&"attack_tokens") as AttackTokenBoard
	if board == null:
		return
	if _extra_interval >= 0.0:
		board.tokens.extra_interval = _extra_interval
	if _hold_time_limit >= 0.0:
		board.tokens.hold_time_limit = _hold_time_limit
	if _retry_block_time >= 0.0:
		board.tokens.retry_block_time = _retry_block_time


## 한 판 싸운다. 결과: time(초), damage, died, timeout, shots, hits
func _fight(target_id: StringName, undead_count: int, skill_id: StringName, run: int) -> Dictionary:
	await _reload_scene(BASE_SEED + run)
	seed(BASE_SEED + run)
	_apply_token_args()
	var region: Node = current_scene
	var necromancer: Necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in region.find_children("*", "EscapePoint", true, false):
		node.free()
	var target: Dictionary = get_target(target_id)
	necromancer.global_position = target.get("start", Vector2.ZERO)
	if target.has("room"):
		_build_room(region, target["room"])

	var data: MonsterData = load(target["data"])
	var spawned: Array[Monster] = []
	var offsets: Array = target["offsets"]
	for i: int in offsets.size():
		var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		# 섞인 무리는 무리원마다 데이터가 다르다 ("datas", offsets와 같은 차례)
		monster.data = load(target["datas"][i]) if target.has("datas") else data
		if _wait_distance >= 0.0:
			# 측정 안에서만 맴도는 거리를 바꾼 데이터 복사본을 쓴다 (.tres는 그대로)
			var copy: MonsterData = monster.data.duplicate()
			copy.token_wait_distance = _wait_distance
			monster.data = copy
		monster.position = target.get("spawn", SPAWN_OFFSET) + offsets[i]
		necromancer.get_parent().add_child(monster)
		spawned.append(monster)
	# 무리면 MonsterPack으로 묶는다: 어그로 공유와 동시 공격 시각 맞추기 (시험 지역의 BatPack과 같다).
	if target.get("pack", false):
		var pack: MonsterPack = MonsterPack.new()
		pack.set_members(spawned)
		region.add_child(pack)
		if target.get("leader", false):
			var settings: PackLeaderSettings = load(LEADER_SETTINGS)
			var leader: Monster = spawned[target.get("leader_index", 0)]
			leader.is_leader = true
			leader.leader_settings = settings
			leader.health = leader.data.max_health * settings.leader_health_ratio
			pack.set_leader(leader, settings.member_damage_ratio)
	if not check_fight_start(TEST_REGION_SCENE, spawned.size()):
		return {"invalid": true}
	# 대장 대상이면 대장이 하나이고 무리원 모두 강화되어 있어야 한다
	var leaders: int = spawned.filter(func(m: Monster) -> bool: return m.is_leader).size()
	var boosted: bool = spawned.all(func(m: Monster) -> bool: return m.damage_ratio > 1.0)
	if target.get("leader", false) and (leaders != 1 or not boosted):
		start_failures += 1
		print("[실패] 판 시작 검사: 대장 %d마리 (기대 1), 무리원 강화 %s. 이 판은 뺀다" % [leaders, boosted])
		return {"invalid": true}
	if target.get("leader", false):
		var leader: Monster = spawned.filter(func(m: Monster) -> bool: return m.is_leader)[0]
		print("[대장] %s: 대장 %d마리 (%s, 체력 %.1f), 무리원 강화 %d/%d" % [target["name"], leaders, leader.data.display_name, leader.health,
				spawned.filter(func(m: Monster) -> bool: return m.damage_ratio > 1.0).size(), spawned.size()])

	var bot: PlayerBot = PlayerBot.new(self, necromancer, skill_id)
	bot.miss_group_attacks = _miss_pack
	if _keep >= 0.0:
		bot.keep_distance = _keep
	if _run_distance >= 0.0:
		bot.run_distance = _run_distance
	if target.has("room"):
		bot.arena_radius = target.get("arena", ROOM_ARENA_RADIUS)
	var skulls: Array[Skull] = []
	if undead_count > 0:
		skulls = _give_undead(necromancer, undead_count)
		bot.set_undead_skulls(skulls)
	var durability_start: float = _total_durability(skulls)
	_on_fight_start(necromancer, bot, spawned)

	var time: float = 0.0
	var delta: float = 1.0 / Engine.physics_ticks_per_second
	var result: Dictionary = {"died": false, "timeout": false}
	var max_health: float = necromancer.max_health
	# 죽으면 지역 씬이 곧바로 거점으로 넘어가 네크로맨서 노드가 사라지므로, 시그널로 기록한다.
	necromancer.died.connect(func() -> void: result["died"] = true)
	while true:
		await physics_frame
		time += delta
		if result["died"] or not is_instance_valid(necromancer):
			result["died"] = true
			break
		if bot_monsters_left() == 0:
			break
		if time >= _timeout:
			result["timeout"] = true
			break
		bot.tick(delta)
		_on_fight_frame(necromancer, bot, time)
	bot.release_all()
	bot.finish_tracking(result["died"])
	result["time"] = time
	result["damage"] = max_health if result["died"] else max_health - necromancer.health
	result["shots"] = bot.shots
	result["hits"] = bot.hits
	result["rolls"] = bot.rolls
	result["telegraphs"] = bot.telegraphs_seen
	result["summons"] = bot.summons
	result["closest"] = bot.closest
	result["group_attacks"] = bot.group_attacks_seen
	result["missed_damage"] = bot.missed_group_damage
	result["mana_after_miss"] = bot.mana_after_miss
	result["mana_min"] = bot.mana_min
	result["undead_died"] = bot.undead_died
	result["undead_released"] = bot.undead_released
	result["durability_lost"] = durability_start - _total_durability(skulls)
	_on_fight_end(result, bot)
	return result


func _total_durability(skulls: Array[Skull]) -> float:
	var total: float = 0.0
	for skull: Skull in skulls:
		total += skull.durability
	return total


## 가운데가 (0, 0)이고 안쪽 크기가 size인 방을 벽으로 둘러싼다 (길찾기 없이 곧장 다니는 볼록한 방이라 NavigationGrid는 넣지 않는다).
func _build_room(region: Node, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = ROOM_WALL_LAYER
	body.collision_mask = 0
	var half: Vector2 = size / 2.0
	var outer: Vector2 = half + Vector2.ONE * ROOM_WALL_THICKNESS / 2.0
	for wall: Array in [[Vector2(0, -outer.y), Vector2(size.x + 2.0 * ROOM_WALL_THICKNESS, ROOM_WALL_THICKNESS)], [Vector2(0, outer.y), Vector2(size.x + 2.0 * ROOM_WALL_THICKNESS, ROOM_WALL_THICKNESS)],
			[Vector2(-outer.x, 0), Vector2(ROOM_WALL_THICKNESS, size.y)], [Vector2(outer.x, 0), Vector2(ROOM_WALL_THICKNESS, size.y)]]:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = wall[1]
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.shape = shape
		collision.position = wall[0]
		body.add_child(collision)
	region.add_child(body)


## 머리뼈 내구도 소모 표 한 줄: 판당 합계와, 모든 판의 소모 합을 싸운 시간 합으로 나눈 초당 소모
func _durability_row(target_id: StringName, undead_count: int, skill_id: StringName, results: Array[Dictionary]) -> String:
	var lost: float = 0.0
	var time: float = 0.0
	for result: Dictionary in results:
		lost += result["durability_lost"]
		time += result["time"]
	return "| %s | 쥐 언데드 %d | %s | %d | %s | %.2f |" % [get_target(target_id)["name"], undead_count, PlayerBot.SKILLS[skill_id]["name"], results.size(),
		_mean_error(results.map(func(r: Dictionary) -> float: return r["durability_lost"]), ""), lost / maxf(time, 0.01)]


## 원인을 재는 스크립트(run_diagnose.gd)가 덮어쓴다: 싸움 시작, 봇이 움직인 뒤 물리 프레임마다, 판이 끝났을 때
func _on_fight_start(_necromancer: Necromancer, _bot: PlayerBot, _spawned: Array[Monster]) -> void:
	pass


func _on_fight_frame(_necromancer: Necromancer, _bot: PlayerBot, _time: float) -> void:
	pass


func _on_fight_end(_result: Dictionary, _bot: PlayerBot) -> void:
	pass


func bot_monsters_left() -> int:
	var count: int = 0
	for node: Node in get_nodes_in_group(&"monsters"):
		if not node.is_queued_for_deletion() and (node as Monster).health > 0.0:
			count += 1
	return count


## 쥐의 머리뼈를 count개 인벤토리에 넣고 핫바 칸에 차례로 놓는다. 봇이 숫자키와 G로 소환한다.
func _give_undead(necromancer: Necromancer, count: int) -> Array[Skull]:
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	var skulls: Array[Skull] = []
	for i: int in count:
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		skulls.append(skull)
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), UNDEAD_BONES))
	return skulls


## 시험 지역을 새로 불러오고, 전역 상태(인벤토리·핫바)를 비운다.
func _reload_scene(run_seed: int) -> void:
	await reload_fight_scene(TEST_REGION_SCENE, run_seed)


## 한 조건의 결과 요약. 시간은 살아서 잡은 판만으로 낸다 (모두 죽거나 시간 초과면 time_mean은 -1).
func _summarize(results: Array[Dictionary]) -> Dictionary:
	var finished: Array[Dictionary] = results.filter(func(r: Dictionary) -> bool: return not r["died"] and not r["timeout"])
	var times: Array = finished.map(func(r: Dictionary) -> float: return r["time"])
	var damages: Array = results.map(func(r: Dictionary) -> float: return r["damage"])
	var shots: int = 0
	var hits: int = 0
	for r: Dictionary in results:
		shots += r["shots"]
		hits += r["hits"]
	var missed: Array[Dictionary] = results.filter(func(r: Dictionary) -> bool: return r["mana_after_miss"] >= 0.0 or r["missed_damage"] > 0.0)
	var after_miss: Array = results.filter(func(r: Dictionary) -> bool: return r["mana_after_miss"] >= 0.0).map(func(r: Dictionary) -> float: return r["mana_after_miss"])
	return {
		"time_mean": _mean(times) if not times.is_empty() else -1.0,
		"time_worst": times.max() if not times.is_empty() else -1.0,
		"damage_mean": _mean(damages),
		"damage_worst": damages.max(),
		"death_rate": 100.0 * results.filter(func(r: Dictionary) -> bool: return r["died"]).size() / results.size(),
		"timeout_rate": 100.0 * results.filter(func(r: Dictionary) -> bool: return r["timeout"]).size() / results.size(),
		"hit_rate": 100.0 * hits / maxi(shots, 1),
		"telegraphs": _mean(results.map(func(r: Dictionary) -> float: return r["telegraphs"])),
		"rolls": _mean(results.map(func(r: Dictionary) -> float: return r["rolls"])),
		"summons": _mean(results.map(func(r: Dictionary) -> float: return r["summons"])),
		"closest": _mean(results.map(func(r: Dictionary) -> float: return r["closest"])),
		"group_attacks": _mean(results.map(func(r: Dictionary) -> float: return r["group_attacks"])),
		# 놓친 동시 공격 열은 실제로 놓친 판(놓친 직후 마나를 잰 판, 또는 놓친 중에 죽은 판)만 평균한다.
		"missed_damage": "%.1f (%d판)" % [_mean(missed.map(func(r: Dictionary) -> float: return r["missed_damage"])), missed.size()] if not missed.is_empty() else "-",
		"mana_after_miss": "%.1f" % _mean(after_miss) if not after_miss.is_empty() else "-",
		"mana_min": _mean(results.map(func(r: Dictionary) -> float: return r["mana_min"])),
		"undead_died": _mean(results.map(func(r: Dictionary) -> float: return r["undead_died"])),
		"undead_released": _mean(results.map(func(r: Dictionary) -> float: return r["undead_released"])),
	}


## 표 한 줄. baseline이 있으면(언데드와 함께인 줄) 혼자 대비 변화를 붙이고, 혼자 줄은 "기준"이다.
func _summary_row(target_id: StringName, undead_count: int, skill_id: StringName, stats: Dictionary, baseline: Variant) -> String:
	var condition: String = "혼자" if undead_count == 0 else "쥐 언데드 %d" % undead_count
	var effect_time: String = "기준"
	var effect_damage: String = "기준"
	var effect_death: String = "기준"
	if undead_count > 0:
		effect_time = "-"
		effect_damage = "-"
		effect_death = "-"
		if baseline != null:
			var base: Dictionary = baseline
			if stats["time_mean"] >= 0.0 and base["time_mean"] >= 0.0:
				effect_time = _change(stats["time_mean"], base["time_mean"], "초")
			effect_damage = _change(stats["damage_mean"], base["damage_mean"], "")
			effect_death = "%+.0f%%p" % (stats["death_rate"] - base["death_rate"])
	return "| %s | %s | %s | %s | %s | %.1f | %.0f | %.0f%% | %.0f%% | %s | %s | %s | %.0f%% | %.1f | %.1f | %.1f | %.0f | %.1f | %s | %s | %.1f | %.1f | %.1f |" % [
		get_target(target_id)["name"], condition, PlayerBot.SKILLS[skill_id]["name"],
		"%.1f초" % stats["time_mean"] if stats["time_mean"] >= 0.0 else "-",
		"%.1f초" % stats["time_worst"] if stats["time_worst"] >= 0.0 else "-",
		stats["damage_mean"], stats["damage_worst"], stats["death_rate"], stats["timeout_rate"],
		effect_time, effect_damage, effect_death,
		stats["hit_rate"], stats["telegraphs"], stats["rolls"], stats["summons"], stats["closest"],
		stats["group_attacks"], stats["missed_damage"], stats["mana_after_miss"],
		stats["mana_min"], stats["undead_died"], stats["undead_released"]]


## 오차 범위 표 한 줄. 시간은 살아서 잡은 판만, 피해와 죽음은 모든 판으로 낸다.
func _error_row(target_id: StringName, undead_count: int, skill_id: StringName, results: Array[Dictionary]) -> String:
	var finished: Array[Dictionary] = results.filter(func(r: Dictionary) -> bool: return not r["died"] and not r["timeout"])
	var deaths: int = results.filter(func(r: Dictionary) -> bool: return r["died"]).size()
	return "| %s | %s | %s | %d | %s | %s | %s |" % [
		get_target(target_id)["name"], "혼자" if undead_count == 0 else "쥐 언데드 %d" % undead_count, PlayerBot.SKILLS[skill_id]["name"], results.size(),
		_mean_error(finished.map(func(r: Dictionary) -> float: return r["time"]), "초"),
		_mean_error(results.map(func(r: Dictionary) -> float: return r["damage"]), ""),
		_rate_range(deaths, results.size())]


## "13.6 ± 1.2초 (43판)": 평균과 95% 오차 범위 (정규 근사: 1.96 × 표준편차 / √판 수)
func _mean_error(values: Array, unit: String) -> String:
	if values.size() < 2:
		return "-"
	var mean: float = _mean(values)
	var squares: float = 0.0
	for v: float in values:
		squares += (v - mean) * (v - mean)
	return "%.1f ± %.1f%s (%d판)" % [mean, 1.96 * sqrt(squares / (values.size() - 1)) / sqrt(values.size()), unit, values.size()]


## "56% (42~69%)": 비율과 95% 범위 (Wilson. 0%나 100% 근처에서도 범위가 0으로 줄지 않는다)
func _rate_range(count: int, total: int) -> String:
	var z: float = 1.96
	var p: float = float(count) / total
	var denominator: float = 1.0 + z * z / total
	var center: float = (p + z * z / (2.0 * total)) / denominator
	var half: float = z * sqrt(p * (1.0 - p) / total + z * z / (4.0 * total * total)) / denominator
	return "%.0f%% (%.0f~%.0f%%)" % [100.0 * p, 100.0 * maxf(center - half, 0.0), 100.0 * minf(center + half, 1.0)]


## 기준 대비 변화: "-2.6초 (-15%)". 기준이 0이면 비율은 뺀다.
func _change(value: float, base: float, unit: String) -> String:
	var diff: float = value - base
	if is_zero_approx(base):
		return "%+.1f%s" % [diff, unit]
	return "%+.1f%s (%+.0f%%)" % [diff, unit, 100.0 * diff / base]


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / values.size()
