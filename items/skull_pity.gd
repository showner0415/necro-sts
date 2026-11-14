class_name SkullPity
extends Resource
## 머리뼈 보정 (계획 7b, docs/game-design.md "몬스터 무리"의 드랍 줄). 노드에 의존하지 않는다.
## - 플레이어에게 머리뼈가 하나도 없으면 skull(쥐의 머리뼈) 드랍 줄의 확률을 boosted_chance로 올린다. 보장은 없다
## - 세는 곳은 인벤토리·소환 중·수리 기계 안이다. 소환 중인 머리뼈와 수리 기계 칸의 머리뼈는 인벤토리에 그대로 있으므로
##   인벤토리만 세면 셋을 다 센다. 창고는 세지 않는다. 내구도 0·네임드 머리뼈도 센다 (사용자 결정, 2026-11-14)
## - 다른 종의 머리뼈 확률은 그대로다 (사용자 결정, 2026-11-14)
## 데이터의 드랍 목록은 바꾸지 않고, 확률을 바꾼 복사본을 돌려준다.

## 기본 값 (data/skull_pity.tres, 처음 쓸 때 한 번 불러 둔다)
const DEFAULT_PATH: String = "res://data/skull_pity.tres"
static var _default: SkullPity

## 보정을 받는 머리뼈
@export var skull: SkullData
## 머리뼈가 하나도 없을 때의 확률 (임시값, 원래 쥐의 머리뼈는 0.5)
@export_range(0.0, 1.0) var boosted_chance: float = 0.8


static func get_default() -> SkullPity:
	if _default == null:
		_default = load(DEFAULT_PATH)
	return _default


## 머리뼈가 하나도 없는지 (skulls: 인벤토리의 머리뼈)
static func has_no_skull(skulls: Array[Skull]) -> bool:
	return skulls.is_empty()


## 드랍 목록. no_skull이면 skull 줄의 확률을 boosted_chance로 올린 복사본을 넣고, 아니면 그대로 돌려준다.
## 원래 확률이 이미 더 높으면 그대로 둔다.
func apply(drops: Array[DropEntry], no_skull: bool) -> Array[DropEntry]:
	if not no_skull or skull == null:
		return drops
	var result: Array[DropEntry] = []
	for entry: DropEntry in drops:
		if entry != null and entry.item != null and entry.item.id == skull.id and entry.chance < boosted_chance:
			var boosted: DropEntry = entry.duplicate()
			boosted.chance = boosted_chance
			result.append(boosted)
		else:
			result.append(entry)
	return result
