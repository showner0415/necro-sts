class_name Summoner
extends Node
## 네크로맨서의 소환 조작. Necromancer 바로 아래 자식으로 둔다.
## - hotbar_1, hotbar_2 …: 핫바 칸 선택
## - summon(G): 선택된 칸의 머리뼈로 소환 / 다시 누르면 해제
## - heal_skull(R): 선택된 칸의 (해제된) 머리뼈 체력을 뼈로 회복
## 규칙은 UndeadRoster가 갖고, 이 노드는 입력을 넘기고 roster의 시그널에 맞춰 언데드 노드를 만들고 없앤다.
## 지역 씬이 bind()로 인벤토리·핫바를 넣어 준다. 안내 문구는 message로 알린다.

signal message(text: String)

@export var undead_scene: PackedScene
## 소환·회복에 쓰는 뼈
@export var bone_item: ItemData
## 언데드가 피해를 한 번 받을 때 줄어드는 머리뼈 내구도 (설계 확정: 1)
@export var durability_loss_per_hit: float = 1.0
## 네크로맨서에게서 이만큼 떨어진 곳에 소환한다 (픽셀, 임시값)
@export var spawn_distance: float = 14.0

var roster: UndeadRoster
var _hotbar: Hotbar
var _undead_nodes: Dictionary[Skull, Undead] = {}

@onready var _necromancer: Necromancer = get_parent()


func bind(inventory: Inventory, hotbar: Hotbar) -> void:
	_hotbar = hotbar
	roster = UndeadRoster.new(inventory, hotbar, _necromancer.mana, bone_item.id, MonsterDatabase.find, durability_loss_per_hit)
	roster.summoned.connect(_spawn)
	roster.unsummoned.connect(_despawn)


## 테스트·디버그용: 그 머리뼈로 소환한 언데드 노드 (없으면 null)
func get_undead(skull: Skull) -> Undead:
	return _undead_nodes.get(skull)


func _physics_process(delta: float) -> void:
	if roster != null:
		roster.process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if roster == null:
		return
	for i: int in _hotbar.get_slot_count():
		if event.is_action_pressed(StringName("hotbar_%d" % (i + 1))):
			_hotbar.select(i)
			return
	# 인벤토리가 열려 있으면 이동만 할 수 있다 (공격·줍기와 같이 막는다).
	if not _necromancer.actions_enabled:
		return
	if event.is_action_pressed(&"summon"):
		toggle_selected()
	elif event.is_action_pressed(&"heal_skull"):
		heal_selected()


func toggle_selected() -> void:
	var skull: Skull = _hotbar.get_selected_skull()
	if skull == null:
		return
	var result: UndeadRoster.Result = roster.toggle(skull)
	if result != UndeadRoster.Result.OK:
		message.emit(_summon_failure_text(skull, result))


func heal_selected() -> void:
	var skull: Skull = _hotbar.get_selected_skull()
	if skull == null:
		return
	var bones_before: int = _necromancer.inventory.get_count(bone_item.id)
	var result: UndeadRoster.Result = roster.heal(skull)
	if result == UndeadRoster.Result.OK:
		var used: int = bones_before - _necromancer.inventory.get_count(bone_item.id)
		message.emit("체력 회복 (%s %d개 사용)" % [bone_item.display_name, used])
	else:
		message.emit(_heal_failure_text(result))


func _summon_failure_text(skull: Skull, result: UndeadRoster.Result) -> String:
	match result:
		UndeadRoster.Result.NOT_ENOUGH_BONES:
			return "%s가 부족함 (%d개 필요)" % [bone_item.display_name, roster.get_monster(skull).summon_bone_cost]
		UndeadRoster.Result.NO_HEALTH:
			return "체력이 없음 - R로 회복"
		UndeadRoster.Result.BROKEN:
			return "내구도가 다 닳아 소환할 수 없음"
		UndeadRoster.Result.NOT_ENOUGH_MANA:
			return "마나가 부족함"
	return "소환할 수 없음"


func _heal_failure_text(result: UndeadRoster.Result) -> String:
	match result:
		UndeadRoster.Result.SUMMONED:
			return "소환 중에는 회복할 수 없음"
		UndeadRoster.Result.NOT_AWAKENED, UndeadRoster.Result.FULL_HEALTH:
			return "체력이 가득 참"
		UndeadRoster.Result.NO_BONES:
			return "%s가 없음" % bone_item.display_name
	return "회복할 수 없음"


func _spawn(skull: Skull) -> void:
	var undead: Undead = undead_scene.instantiate()
	undead.setup(skull, roster.get_monster(skull), _necromancer)
	# 멀리 떨어져 따라갈 때는 네크로맨서가 뛰는 속도까지 빨라진다.
	undead.catch_up_speed = _necromancer.run_speed
	undead.damage_received.connect(roster.damage)
	_undead_nodes[skull] = undead
	_necromancer.get_parent().add_child(undead)
	undead.global_position = _necromancer.global_position + Vector2.from_angle(randf() * TAU) * spawn_distance


func _despawn(skull: Skull, _died: bool) -> void:
	var undead: Undead = _undead_nodes.get(skull)
	_undead_nodes.erase(skull)
	if is_instance_valid(undead):
		undead.queue_free()
