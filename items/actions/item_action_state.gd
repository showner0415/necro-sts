class_name ItemActionState
extends RefCounted
## 메뉴 항목 하나의 지금 상태.
## - enabled가 false면 회색으로 보이고 reason(예: "소환 중")을 같이 적는다
## - warning이 있으면 쓸 수는 있지만 결과를 경고한다 (예: "죽은 판정이 됩니다")

var enabled: bool = true
var reason: String = ""
var warning: String = ""


static func available(warning_text: String = "") -> ItemActionState:
	var state: ItemActionState = ItemActionState.new()
	state.warning = warning_text
	return state


static func unavailable(reason_text: String) -> ItemActionState:
	var state: ItemActionState = ItemActionState.new()
	state.enabled = false
	state.reason = reason_text
	return state
