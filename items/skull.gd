class_name Skull
extends Resource
## 실제로 가진 머리뼈 하나. 같은 종류라도 하나하나 따로 존재하고, 각자 내구도와 언데드 체력을 가진다.
## - 내구도: 언데드가 피해를 받거나 죽으면 줄어든다. 0이면 소환할 수 없다.
## - 체력: 이 머리뼈로 소환한 언데드의 체력. 해제해도 그대로 남고, 뼈를 써서 회복한다.
## - 깨움(awakened): 처음 소환할 때 뼈를 써서 깨운다. 깨우기 전에는 체력이 의미 없고, 깨울 때 가득 찬다.
## 값을 바꾸는 규칙은 UndeadRoster가 가진다. 네임드(이름 있는 머리뼈)는 아직 없다.

@export var data: SkullData
@export var durability: float
@export var awakened: bool = false
@export var health: float = 0.0


static func create(skull_data: SkullData) -> Skull:
	var skull: Skull = Skull.new()
	skull.data = skull_data
	skull.durability = skull_data.max_durability
	return skull


## 화면에 보여줄 이름. 네임드가 생기면 "전사 XXX의 머리뼈"처럼 여기서 바뀐다.
func get_display_name() -> String:
	return data.display_name


func is_broken() -> bool:
	return durability <= 0.0


func lose_durability(amount: float) -> void:
	durability = maxf(durability - amount, 0.0)
