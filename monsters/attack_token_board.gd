class_name AttackTokenBoard
extends Node
## 지역 하나의 공격권(AttackTokens)을 드는 노드 (그룹 attack_tokens). 지역(Region)이 시작할 때 하나 넣는다.
## 공격권은 대상마다 모든 몬스터가 함께 세므로 무리 밖에 둔다. 몬스터는 처음 공격하려 할 때 그룹에서 찾는다 (없으면 제한 없이 공격한다).
## 몬스터들이 물리 프레임에 공격권을 물은 뒤 update()가 돌도록, 지역의 자식 중 Actors보다 뒤에 둔다.

## 공격권이 다 찼을 때 기다리는 몬스터 중 하나에게 추가 공격권을 주는 간격 (초, 사용자 결정 2026-11-13)
@export var extra_interval: float = 1.0
## 공격권을 이 시간(초)보다 오래 들고 있으면 반납한다 (공격권이 묶이는 버그 방지, 임시값)
@export var hold_time_limit: float = 4.0
## 이 거리(픽셀) 이상 밀려나면 공격권을 반납한다 (밀친 거리로 잰다, 임시값)
@export var knockback_release_distance: float = 48.0

var tokens: AttackTokens


func _init() -> void:
	add_to_group(&"attack_tokens")


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = randi()
	tokens = AttackTokens.new(extra_interval, hold_time_limit, rng)


func _physics_process(delta: float) -> void:
	tokens.update(delta)
