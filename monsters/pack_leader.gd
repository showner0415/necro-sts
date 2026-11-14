class_name PackLeader
extends RefCounted
## 무리 대장 고르기 규칙 (계획 6a). 노드에 의존하지 않는다.
## - 무리를 만들 때 chance 확률로 대장이 생긴다. 확정(forced)이면 반드시 생긴다 (퀘스트 대상 무리, DungeonRun의 확정 목록)
## - 대장은 무리원 중 던전 시드 난수로 아무나 된다 (종과 상관없이, 사용자 결정 2026-11-14)
## 난수는 확률 한 번, 번호 한 번 쓴다 (확정이면 확률은 쓰지 않는다).
## - 대장을 잡으면 확률로 네임드 머리뼈가 나온다 (rolls_named_skull, 계획 6b)


## 대장이 될 무리원 번호 (0부터). 대장이 없으면 -1.
static func pick(count: int, chance: float, forced: bool, rng: RandomNumberGenerator) -> int:
	if count <= 0:
		return -1
	if not forced and rng.randf() >= chance:
		return -1
	return rng.randi_range(0, count - 1)


## 대장을 잡았을 때 네임드 머리뼈가 나오는지 (계획 6b). 난수를 한 번 쓴다.
static func rolls_named_skull(chance: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < chance
