class_name Skull
extends Resource
## 실제로 가진 머리뼈 하나. 같은 종류라도 하나하나 따로 존재하고, 각자 내구도와 언데드 체력을 가진다.
## - 내구도: 언데드가 피해를 받거나 죽으면 줄어든다. 0이면 소환할 수 없다.
## - 체력: 이 머리뼈로 소환한 언데드의 체력. 해제해도 그대로 남고, 뼈를 써서 회복한다.
## - 깨움(awakened): 처음 소환할 때 뼈를 써서 깨운다. 깨우기 전에는 체력이 의미 없고, 깨울 때 가득 찬다.
## 값을 바꾸는 규칙은 UndeadRoster가 가진다.
## - 네임드(이름 있는 머리뼈, 계획 6b): named_name이 있으면 "쥐 그레카의 머리뼈"처럼 보이고, 소환한 언데드는 네임드 배율(UndeadStatRules.named_*)을 쓴다.
##   지금은 무리 대장이 주는 임시 네임드뿐이다 (고정 이름 하나)

@export var data: SkullData
@export var durability: float
@export var awakened: bool = false
@export var health: float = 0.0
## 네임드 이름 (비면 일반 머리뼈)과, 이름에 붙일 원래 몬스터 이름 (예: "쥐")
@export var named_name: String = ""
@export var source_name: String = ""

## 네임드 이름 꼴: "<원래 몬스터> <이름>의 머리뼈" (docs/game-design.md "머리뼈")
const NAMED_FORMAT: String = "%s %s의 머리뼈"


static func create(skull_data: SkullData) -> Skull:
	var skull: Skull = Skull.new()
	skull.data = skull_data
	skull.durability = skull_data.max_durability
	return skull


## 네임드 머리뼈 하나. monster_name은 원래 몬스터 이름(MonsterData.display_name), name은 네임드 이름.
static func create_named(skull_data: SkullData, monster_name: String, name: String) -> Skull:
	var skull: Skull = create(skull_data)
	skull.source_name = monster_name
	skull.named_name = name
	return skull


func is_named() -> bool:
	return not named_name.is_empty()


## 화면에 보여줄 이름. 네임드면 "쥐 그레카의 머리뼈".
func get_display_name() -> String:
	return NAMED_FORMAT % [source_name, named_name] if is_named() else data.display_name


func is_broken() -> bool:
	return durability <= 0.0


func lose_durability(amount: float) -> void:
	durability = maxf(durability - amount, 0.0)
