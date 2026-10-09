class_name PressTracker
extends RefCounted
## 누름 → 이동 → 뗌 한 번의 제스처를 판정하는 순수 로직 (롱프레스 없음).
##   - 아이템을 누르고 SLOP 넘게 움직이면 즉시 드래그, 안 움직이고 떼면 아이템 탭
##   - 빈 곳을 누르고 SLOP 넘게 움직이면 스크롤, 안 움직이고 떼면 빈 곳 탭
## 마우스와 터치(에뮬레이션된 마우스)가 같은 규칙을 쓴다.

enum Phase { IDLE, ITEM_PENDING, DRAGGING, EMPTY_PENDING, SCROLLING }
enum Outcome { NONE, DRAG_STARTED, SCROLL_STARTED, TAP_ITEM, TAP_EMPTY, DRAG_ENDED, SCROLL_ENDED }

## 이 거리(논리 픽셀)를 넘게 움직여야 탭이 아니라 이동으로 본다.
const SLOP: float = 10.0

var phase: Phase = Phase.IDLE
var origin: Vector2 = Vector2.ZERO


func press(pos: Vector2, on_item: bool) -> void:
	origin = pos
	phase = Phase.ITEM_PENDING if on_item else Phase.EMPTY_PENDING


## 포인터가 움직였을 때. 드래그·스크롤이 막 시작되면 그 결과를, 아니면 NONE.
func move(pos: Vector2) -> Outcome:
	if phase == Phase.ITEM_PENDING and pos.distance_to(origin) > SLOP:
		phase = Phase.DRAGGING
		return Outcome.DRAG_STARTED
	if phase == Phase.EMPTY_PENDING and pos.distance_to(origin) > SLOP:
		phase = Phase.SCROLLING
		return Outcome.SCROLL_STARTED
	return Outcome.NONE


func release(_pos: Vector2) -> Outcome:
	var previous: Phase = phase
	phase = Phase.IDLE
	match previous:
		Phase.ITEM_PENDING:
			return Outcome.TAP_ITEM
		Phase.EMPTY_PENDING:
			return Outcome.TAP_EMPTY
		Phase.DRAGGING:
			return Outcome.DRAG_ENDED
		Phase.SCROLLING:
			return Outcome.SCROLL_ENDED
	return Outcome.NONE


func cancel() -> void:
	phase = Phase.IDLE


func is_idle() -> bool:
	return phase == Phase.IDLE


func is_dragging() -> bool:
	return phase == Phase.DRAGGING


func is_scrolling() -> bool:
	return phase == Phase.SCROLLING
