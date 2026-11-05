class_name RegionData
extends Resource
## 지역 하나(거점 포함)의 정의. 탈출 지점·출구·죽었을 때 돌아갈 곳이 이 리소스로 목적지를 가리킨다.
## 씬끼리 서로를 가리키므로(지역 → 거점 → 지역) PackedScene 대신 경로 문자열로 둔다.
## PackedScene으로 두면 두 씬이 서로를 불러오려 해서 Godot가 불러오지 못한다.

@export var id: StringName
@export var display_name: String
@export_file("*.tscn") var scene_path: String
## true면 거점 (몬스터가 없는 안전한 곳)
@export var is_base: bool = false
