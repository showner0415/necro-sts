extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): inventory_open.gd처럼 인벤토리를 열고, 머리뼈 칸 하나를 끄는 중으로 만든다.
## 끄는 동안 마우스를 따라다니는 그림(InventorySlot.make_drag_preview)이 칸 그림(아이템 데이터의 icon, 비면 임시 도형)과 같은지 볼 때 쓴다.
## 끌기는 Control.force_drag로 시작하고, 끄는 그림을 빈 칸(DROP_INDEX) 가운데로 옮겨 둔다
## (창 모드에서는 넣은 마우스 입력이 아니라 실제 커서 자리를 따라가서 직접 옮긴다).
## 찍는 동안 실제 마우스를 창 위에서 움직이면 끄는 그림이 커서로 따라간다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --setup=res://tools/screenshot_setups/drag_preview.gd --out=<경로>

const INVENTORY_OPEN_PATH: String = "res://tools/screenshot_setups/inventory_open.gd"
## 끌 칸 (inventory_open.gd의 첫 머리뼈, 쥐)
const DRAG_INDEX: int = 1
## 끄는 그림을 둘 빈 칸
const DROP_INDEX: int = 8
## 창이 자리 잡은 뒤에 끌기 시작하도록 기다리는 시간 (초)
const DRAG_DELAY: float = 0.5


static func run(scene: Node) -> void:
	load(INVENTORY_OPEN_PATH).run(scene)
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	scene.get_tree().create_timer(DRAG_DELAY).timeout.connect(func() -> void:
		var slot: InventorySlot = screen.get_slot_control(DRAG_INDEX)
		var stack: ItemStack = slot.get_stack()
		var data: Dictionary = {InventorySlot.DRAG_KEY: DRAG_INDEX, InventorySlot.DRAG_CONTAINER_KEY: slot.container, InventorySlot.DRAG_SKULL_KEY: stack.skull}
		var preview: Control = InventorySlot.make_drag_preview(stack.item)
		slot.force_drag(data, preview)
		preview.global_position = screen.get_slot_control(DROP_INDEX).get_global_rect().get_center())
