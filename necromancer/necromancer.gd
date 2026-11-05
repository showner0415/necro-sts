class_name Necromancer
extends CharacterBody2D
## 플레이어 캐릭터.
## move_* 입력으로 움직이고(run을 누르고 있으면 뛰기, roll로 구르기. 둘 다 스태미나를 쓴다), attack을 누르고 있으면 마우스 방향으로 약한 탄을 쏘고 (마나 비용은 attack 데이터),
## pickup을 누르면 줍기 범위 안에서 가장 가까운 아이템 더미를 인벤토리에 넣는다.
## 인벤토리는 이 노드가 아니라 전역 상태(GameState)에 있고, 지역 씬이 inventory에 넣어 준다.

signal health_changed(current: float, maximum: float)
signal died

@export var move_speed: float = 80.0
@export var max_health: float = 10.0
@export var max_mana: float = 20.0
## 초당 마나 자연 회복량
@export var mana_regen_per_second: float = 1.0
## 이 거리 안의 아이템을 주울 수 있다
@export var pickup_range: float = 16.0
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1

@export_group("뛰기·구르기")
## 뛰기 키를 누르고 움직일 때의 속도 (임시값)
@export var run_speed: float = 130.0
## 스태미나 최대치 (임시값)
@export var max_stamina: float = 100.0
## 뛰지도 구르지도 않을 때 초당 회복량 (임시값)
@export var stamina_regen_per_second: float = 30.0
## 뛰는 동안 초당 쓰는 스태미나 (임시값)
@export var run_stamina_per_second: float = 25.0
## 구르기 한 번에 쓰는 스태미나 (임시값)
@export var roll_stamina_cost: float = 25.0
## 구르기 한 번에 움직이는 거리 (픽셀, 임시값)
@export var roll_distance: float = 64.0
## 구르는 시간 (초, 임시값)
@export var roll_duration: float = 0.3
## 구르기를 시작하고 이 시간 동안은 피해를 받지 않는다 (초, 임시값)
@export var roll_invincible_duration: float = 0.2

@export_group("버리기")
## 인벤토리에서 버린 물건을 바닥에 놓을 씬
@export var pickup_scene: PackedScene
## 발밑에서 이 거리 안에 이미 물건이 있으면 겹치지 않게 흩뜨린다
@export var drop_overlap_distance: float = 4.0
## 흩뜨릴 때 발밑에서 떨어뜨리는 거리
@export var drop_scatter_radius: float = 8.0

@export_group("기본 공격")
## 피해량·마나 비용·간격·탄속·사거리는 이 데이터를 따른다
@export var attack: AttackData
@export var bolt_scene: PackedScene

@export_group("임시 도형")
@export var placeholder_color: Color = Color(0.5647059, 0.36862746, 0.6627451, 1)
## 그림과 충돌 판정에 같이 쓰는 원의 반지름
@export var placeholder_radius: float = 6.0

var health: float
var mana: ManaPool
var stamina: Stamina
## 지금 뛰고 있는지 (뛰기 키 + 이동 + 스태미나)
var is_running: bool = false
## 구르기를 시작하고 지난 시간. 구르는 중이 아니면 음수.
var _roll_elapsed: float = -1.0
var _roll_direction: Vector2 = Vector2.ZERO
## 지역 씬이 GameState의 인벤토리를 넣어 준다
var inventory: Inventory
## false면 이동만 하고 공격과 줍기는 하지 않는다 (인벤토리가 열려 있을 때 등)
var actions_enabled: bool = true
var _attack_timer: float = 0.0
## 게임 화면에서(UI가 아닌 곳에서) 공격 버튼을 눌러 아직 떼지 않았는지
var _attack_held: bool = false
## 지금 키 안내를 띄운 더미
var _prompted_pickup: Pickup

@onready var summoner: Summoner = $Summoner
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _pickup_area: Area2D = $PickupArea
@onready var _pickup_collision: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var _stamina_ring: StaminaRing = $StaminaRing


func _ready() -> void:
	health = max_health
	mana = ManaPool.new(max_mana, mana_regen_per_second)
	stamina = Stamina.new(max_stamina, stamina_regen_per_second, run_stamina_per_second, roll_stamina_cost)
	_stamina_ring.bind(stamina)
	var body_shape: CircleShape2D = CircleShape2D.new()
	body_shape.radius = placeholder_radius
	_collision.shape = body_shape
	_collision.position = Vector2(0, -placeholder_radius)
	var pickup_shape: CircleShape2D = CircleShape2D.new()
	pickup_shape.radius = pickup_range
	_pickup_collision.shape = pickup_shape


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# 뛰기 키는 UI와 겹치지 않으므로 직접 읽는다. 떼면 지친 상태가 풀린다.
	var run_held: bool = Input.is_action_pressed(&"run")
	if not run_held:
		stamina.release_run()
	var rolling: bool = is_rolling()
	if rolling:
		velocity = _roll_direction * (roll_distance / roll_duration)
		is_running = false
	else:
		is_running = run_held and input_direction != Vector2.ZERO and stamina.can_run()
		velocity = input_direction * (run_speed if is_running else move_speed)
	move_and_slide()
	stamina.process(delta, is_running, rolling)
	if rolling:
		_roll_elapsed += delta
		if _roll_elapsed >= roll_duration:
			_roll_elapsed = -1.0

	mana.regenerate(delta)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	# 뗀 것은 직접 읽는다: 떼는 순간 마우스가 UI 위에 있어도 공격이 멈추게 한다.
	if not Input.is_action_pressed(&"attack"):
		_attack_held = false
	if actions_enabled and _attack_held and _attack_timer == 0.0:
		_shoot()

	_update_pickup_prompt()


## UI가 받은 입력은 여기로 오지 않는다. 그래서 핫바·인벤토리를 클릭해도 공격이 시작되지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_attack_held = true
	if actions_enabled and event.is_action_pressed(&"pickup"):
		_pick_up_nearest()
	# 구르기도 이동이라 인벤토리가 열려 있어도 된다. UI가 Space를 받으면(버튼 누르기) 여기로 오지 않는다.
	if event.is_action_pressed(&"roll"):
		try_roll()


## 이동 방향으로 구른다. 멈춰 있으면 마우스 방향. 스태미나가 모자라거나 이미 구르는 중이면 false.
func try_roll() -> bool:
	if is_rolling():
		return false
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").normalized()
	if direction == Vector2.ZERO:
		direction = global_position.direction_to(get_global_mouse_position())
	if direction == Vector2.ZERO or not stamina.try_roll():
		return false
	_roll_direction = direction
	_roll_elapsed = 0.0
	return true


func is_rolling() -> bool:
	return _roll_elapsed >= 0.0


## 구르기 시작 뒤 roll_invincible_duration 동안 무적
func is_invincible() -> bool:
	return is_rolling() and _roll_elapsed < roll_invincible_duration


## 테스트·디버그용: 게임 화면에서 누른 공격 버튼을 아직 떼지 않았는지.
## 인벤토리가 열려 있어 탄이 나가지 않을 때도, UI 클릭이 게임 조작으로 새어 나갔는지 이것으로 알 수 있다.
func is_attack_held() -> bool:
	return _attack_held


func take_damage(amount: float) -> void:
	if health <= 0.0 or is_invincible():
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health == 0.0:
		died.emit()
		return
	modulate = Color(3, 3, 3)
	create_tween().tween_property(self, "modulate", Color.WHITE, hit_flash_duration)


func _shoot() -> void:
	# 발밑이 아니라 몸 가운데에서 쏜다.
	var origin: Vector2 = global_position + Vector2(0, -placeholder_radius)
	var direction: Vector2 = origin.direction_to(get_global_mouse_position())
	if direction == Vector2.ZERO:
		return
	# 마나가 모자라면 쏘지 않는다. 자연 회복될 때까지 기다려야 한다.
	if not mana.try_spend(attack.mana_cost):
		return
	_attack_timer = attack.cooldown
	var bolt: Bolt = bolt_scene.instantiate()
	bolt.direction = direction
	bolt.speed = attack.projectile_speed
	bolt.damage = attack.damage
	bolt.max_distance = attack.projectile_range
	get_parent().add_child(bolt)
	bolt.global_position = origin


## 인벤토리에서 꺼낸 물건을 발밑에 바닥 더미로 놓는다. 다시 주울 수 있다.
func drop_to_ground(stack: ItemStack) -> void:
	var drop_position: Vector2 = global_position
	if _has_pickup_near(drop_position):
		drop_position += Vector2.from_angle(randf() * TAU) * drop_scatter_radius
	var pickup: Pickup = pickup_scene.instantiate()
	pickup.stack = stack
	get_parent().add_child(pickup)
	pickup.global_position = drop_position


func _has_pickup_near(point: Vector2) -> bool:
	for area: Area2D in _pickup_area.get_overlapping_areas():
		if area is Pickup and area.global_position.distance_to(point) < drop_overlap_distance:
			return true
	return false


func _pick_up_nearest() -> void:
	var nearest: Pickup = _find_nearest_pickup()
	if nearest == null:
		return
	# 칸이 가득 차서 넣지 못하면 바닥에 그대로 둔다.
	if inventory.try_add(nearest.stack):
		nearest.queue_free()


## 줍기 키를 누르면 주워질 더미(줍기 범위 안에서 가장 가까운 것) 위에만 안내를 띄운다.
## 인벤토리에 자리가 없으면 키 안내 대신 "인벤토리 가득 참"이 뜬다.
## 공격·줍기가 막혀 있으면 아무 데도 띄우지 않는다.
func _update_pickup_prompt() -> void:
	var target: Pickup = _find_nearest_pickup() if actions_enabled else null
	if target != _prompted_pickup and is_instance_valid(_prompted_pickup):
		_prompted_pickup.set_prompt(false)
	_prompted_pickup = target
	if target != null:
		# 줍지 않아도 칸이 비거나 찰 수 있으므로(버리기 등) 매 프레임 다시 정한다.
		target.set_prompt(true, inventory.can_add(target.stack))


func _find_nearest_pickup() -> Pickup:
	var nearest: Pickup = null
	var nearest_distance: float = INF
	for area: Area2D in _pickup_area.get_overlapping_areas():
		var pickup: Pickup = area as Pickup
		if pickup == null or pickup.is_queued_for_deletion():
			continue
		var distance: float = global_position.distance_squared_to(pickup.global_position)
		if distance < nearest_distance:
			nearest = pickup
			nearest_distance = distance
	return nearest


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형. 기준점(발밑) 위에 원을 그린다.
	draw_circle(Vector2(0, -placeholder_radius), placeholder_radius, placeholder_color)
