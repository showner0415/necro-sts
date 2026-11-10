class_name Corpse
extends GroundTarget
## 몬스터가 죽은 자리에 남는 시체. 죽을 때 정해진 아이템(loot)을 담고 있고, 네크로맨서가 E로 한 묶음씩 채집한다.
## 안에 무엇이 남았는지는 보여주지 않는다. 다 채집하면 빈 시체로 남아 empty_color로 그려지고, 더는 E 대상이 아니다.

## 다 채집한 빈 시체의 색
@export var empty_color: Color = Color(0.4509804, 0.24313726, 0.22352941, 1)
## 누운 모양으로 그리려고 원의 세로를 이 비율로 줄인다
@export var flatten_ratio: float = 0.5

var data: MonsterData
var loot: CorpseLoot

@onready var _collision: CollisionShape2D = $CollisionShape2D


## 몬스터가 죽을 때 넣어 준다. 트리에 넣기 전에 부른다.
func setup(monster_data: MonsterData, corpse_loot: CorpseLoot) -> void:
	data = monster_data
	loot = corpse_loot


func _ready() -> void:
	super()
	_collision.shape = PlaceholderBody.make_shape(data)
	_collision.rotation = PlaceholderBody.shape_rotation(data)


func get_display_name() -> String:
	return "%s의 시체" % data.display_name


func is_available() -> bool:
	return not loot.is_empty()


func can_receive(inventory: Inventory) -> bool:
	return loot.can_harvest(inventory)


## stack을 인벤토리에 넣고 시체에서 뺀다. 자리가 없으면 시체에 남기고 false.
func take(stack: ItemStack, inventory: Inventory) -> bool:
	if not loot.take(stack, inventory):
		return false
	if loot.is_empty():
		set_prompt(false)
		queue_redraw()
	return true


## 임시 도형의 지금 색. 3D 화면 층이 읽는다.
func get_placeholder_tint() -> Color:
	return empty_color if loot.is_empty() else data.placeholder_color


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형: 원본 몬스터의 도형을 납작하게 눕힌 모양.
	PlaceholderBody.draw(self, data, get_placeholder_tint(), Vector2.ZERO, flatten_ratio)
