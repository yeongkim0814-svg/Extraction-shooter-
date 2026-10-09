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
const STASH_LOCKED := &"stash_locked"
const NOT_A_WEAPON := &"not_a_weapon"
const WEAPON_NOT_EQUIPPED := &"weapon_not_equipped"
const MAGAZINE_FULL := &"magazine_full"
const NO_AMMO := &"no_ammo"
const NOT_A_PART := &"not_a_part"
const HAS_ATTACHMENTS := &"has_attachments"
## 수색으로 아직 공개되지 않은 아이템.
const NOT_REVEALED := &"not_revealed"
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
