extends RefCounted
## 길찾기 격자 확인: 벽 타일에서 바로 계산한 막힌 칸(NavigationGrid.make_grid_from_tiles)이 물리 질의로 잰 것(make_grid_from_physics)과 같은지,
## 몸 크기마다 비교하고 걸린 시간을 잰다. scenario_pathfinding.gd(칸 8px, 몸이 타일 경계에 딱 닿는 경우가 있음)와
## scenario_shallow_cave.gd(큰 맵)가 같이 쓴다.

const BODY_DATA: Array[String] = ["res://data/monsters/rat.tres", "res://data/monsters/boar.tres", "res://data/monsters/bat.tres", "res://data/monsters/goblin_slinger.tres"]


## 네크로맨서와 몬스터 데이터들의 몸 반 크기마다 비교한다. {"ok": 모두 같음, "lines": [몸 크기마다 설명], "tile_ms": 타일 계산 합계, "physics_ms": 물리 질의 합계}
static func compare(nav: NavigationGrid, walls: PlaceholderWalls, necromancer_radius: float) -> Dictionary:
	var sizes: Array[Vector2] = [Vector2(necromancer_radius, necromancer_radius)]
	for path: String in BODY_DATA:
		sizes.append((load(path) as MonsterData).get_placeholder_half_size())
	var ok: bool = true
	var lines: PackedStringArray = []
	var tile_total: int = 0
	var physics_total: int = 0
	for half: Vector2 in sizes:
		var started: int = Time.get_ticks_usec()
		var physics: GridPath = nav.make_grid_from_physics(half)
		var physics_us: int = Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		var tiles: GridPath = nav.make_grid_from_tiles(half, walls)
		var tile_us: int = Time.get_ticks_usec() - started
		var different: int = 0
		var size: Vector2i = physics.get_size()
		for y: int in size.y:
			for x: int in size.x:
				if physics.is_solid(Vector2i(x, y)) != tiles.is_solid(Vector2i(x, y)):
					different += 1
		ok = ok and different == 0
		tile_total += tile_us
		physics_total += physics_us
		lines.append("몸 %s: 다른 칸 %d, 타일 %dms / 물리 %dms" % [half, different, tile_us / 1000, physics_us / 1000])
	return {"ok": ok, "lines": lines, "tile_ms": tile_total / 1000, "physics_ms": physics_total / 1000}
