class_name Pickup
extends GroundTarget
## 바닥에 떨어진 물건 더미 (인벤토리에서 버린 것). 안에 ItemStack 하나(뼈 N개 또는 머리뼈 하나)를 담는다.
## 네크로맨서가 근처에서 줍기 키를 누르면 인벤토리로 들어간다. 안내는 GroundTarget이 띄운다.

var stack: ItemStack


func get_display_name() -> String:
	return stack.get_display_name()


func can_receive(inventory: Inventory) -> bool:
	return inventory.can_add(stack)


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형. 기준점(바닥) 위에 사각형을 그린다.
	var size: Vector2 = stack.item.placeholder_size
	draw_rect(Rect2(Vector2(-size.x / 2.0, -size.y), size), stack.item.placeholder_color)
