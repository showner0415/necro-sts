extends RefCounted
## 스크린샷 준비: 거점으로 간다. 거점의 기본 시작 위치(출구 아래)에서 찍힌다.

const BASE_DATA_PATH: String = "res://data/regions/base.tres"


static func run(scene: Node) -> void:
	(scene as Region).travel_to(load(BASE_DATA_PATH))
