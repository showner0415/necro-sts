class_name ItemActionState
extends RefCounted
## 메뉴 항목 하나의 지금 상태.
## - enabled가 false면 회색으로 보이고 reason(예: "소환 중")을 같이 적는다
## - warning이 있으면 쓸 수는 있지만 결과를 경고한다. warning_kind로 경고의 무게를 나눈다
##   - CAUTION: 되돌릴 수 있는 결과 (예: "소환이 해제됩니다"). 노란색
##   - LOSS: 되돌릴 수 없는 손해 (예: "죽은 판정이 됩니다"). 빨간색 (docs/art-direction.md의 경고 색 규칙)

enum WarningKind { CAUTION, LOSS }

var enabled: bool = true
var reason: String = ""
var warning: String = ""
var warning_kind: WarningKind = WarningKind.CAUTION


static func available(warning_text: String = "", kind: WarningKind = WarningKind.CAUTION) -> ItemActionState:
	var state: ItemActionState = ItemActionState.new()
	state.warning = warning_text
	state.warning_kind = kind
	return state


static func unavailable(reason_text: String) -> ItemActionState:
	var state: ItemActionState = ItemActionState.new()
	state.enabled = false
	state.reason = reason_text
	return state
