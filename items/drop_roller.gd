class_name DropRoller
extends RefCounted
## 드랍 확률 계산 규칙. 노드에 의존하지 않는다.


## 드랍 목록의 줄마다 확률을 굴려서, 떨어뜨리기로 정해진 줄만 돌려준다.
## rng를 주면 그것으로 굴리고(테스트에서 시드 고정용), 없으면 전역 난수(randf)를 쓴다.
static func roll(entries: Array[DropEntry], rng: RandomNumberGenerator = null) -> Array[DropEntry]:
	var result: Array[DropEntry] = []
	for entry: DropEntry in entries:
		if entry == null or entry.item == null or entry.count <= 0:
			continue
		var roll_value: float = rng.randf() if rng != null else randf()
		# randf()는 0 이상 1 미만이므로 확률 1은 항상, 0은 절대 성공하지 않는다.
		if roll_value < entry.chance:
			result.append(entry)
	return result
