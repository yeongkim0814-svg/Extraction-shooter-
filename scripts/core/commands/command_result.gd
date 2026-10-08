class_name CommandResult
extends RefCounted
## 명령 실행 결과. 실패하면 상태는 바뀌지 않았고 error에 이유 코드가 담긴다.

const UNKNOWN_ITEM := &"unknown_item"
const UNKNOWN_CONTAINER := &"unknown_container"
const NO_SPACE := &"no_space"
const NESTING_NOT_ALLOWED := &"nesting_not_allowed"
const SLOT_NOT_ALLOWED := &"slot_not_allowed"
const SLOT_OCCUPIED := &"slot_occupied"
const NOT_STACKABLE := &"not_stackable"
const INVALID_AMOUNT := &"invalid_amount"
const ALREADY_ADDED := &"already_added"
const NOT_IMPLEMENTED := &"not_implemented"

var ok: bool
var error: StringName = &""
var events: Array[DomainEvent] = []


static func success(p_events: Array[DomainEvent] = []) -> CommandResult:
	var result := CommandResult.new()
	result.ok = true
	result.events = p_events
	return result


static func failure(p_error: StringName) -> CommandResult:
	var result := CommandResult.new()
	result.ok = false
	result.error = p_error
	return result
