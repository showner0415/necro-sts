class_name Skull
extends Resource
## 실제로 가진 머리뼈 하나. 같은 종류라도 하나하나 따로 존재하고, 각자 현재 내구도를 가진다.
## 내구도가 줄어드는 규칙과 네임드(이름 있는 머리뼈)는 아직 없다. 생기면 이 클래스에 더한다.

@export var data: SkullData
@export var durability: float


static func create(skull_data: SkullData) -> Skull:
	var skull: Skull = Skull.new()
	skull.data = skull_data
	skull.durability = skull_data.max_durability
	return skull


## 화면에 보여줄 이름. 네임드가 생기면 "전사 XXX의 머리뼈"처럼 여기서 바뀐다.
func get_display_name() -> String:
	return data.display_name
