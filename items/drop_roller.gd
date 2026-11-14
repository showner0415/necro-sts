class_name DropRoller
extends RefCounted
## 드랍 확률 계산 규칙. 노드에 의존하지 않는다.
## - 줄마다 chance로 떨어뜨릴지 굴린다
## - 기대값 줄(expected_count > 0)은 개수를 정수 부분 확정 + 소수 부분 확률로 정한다 (roll_count). 0개가 되면 그 줄은 빠진다


## 드랍 목록의 줄마다 확률을 굴려서, 떨어뜨리기로 정해진 줄만 돌려준다. 기대값 줄은 굴린 개수를 count에 넣은 복사본이다.
## rng를 주면 그것으로 굴리고(던전 시드 난수, 테스트에서 시드 고정용), 없으면 전역 난수(randf)를 쓴다.
static func roll(entries: Array[DropEntry], rng: RandomNumberGenerator = null) -> Array[DropEntry]:
	var result: Array[DropEntry] = []
	for entry: DropEntry in entries:
		if entry == null or entry.item == null:
			continue
		if entry.expected_count <= 0.0 and entry.count <= 0:
			continue
		var roll_value: float = rng.randf() if rng != null else randf()
		# randf()는 0 이상 1 미만이므로 확률 1은 항상, 0은 절대 성공하지 않는다.
		if roll_value >= entry.chance:
			continue
		if entry.expected_count > 0.0:
			var rolled: DropEntry = entry.duplicate()
			rolled.count = roll_count(entry.expected_count, rng)
			if rolled.count > 0:
				result.append(rolled)
		else:
			result.append(entry)
	return result


## 기대값 expected로 개수를 정한다: 정수 부분은 확정, 소수 부분은 그 확률로 하나 더.
static func roll_count(expected: float, rng: RandomNumberGenerator = null) -> int:
	if expected <= 0.0:
		return 0
	var whole: int = floori(expected)
	var roll_value: float = rng.randf() if rng != null else randf()
	return whole + (1 if roll_value < expected - whole else 0)
