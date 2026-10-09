class_name ModStats
extends RefCounted
## 모딩 화면의 스탯 표시 규칙 (순수 로직): 어떤 스탯을 어떤 단위·자릿수로 보이고, 부품을 달/뗄 때의 변화가
## 좋아지는지 나빠지는지(반동·퍼짐·무게·소음은 낮을수록 좋음), 달아 보기 전 미리보기 계산.

enum Verdict { SAME, BETTER, WORSE }

const BETTER_COLOR := Color(0.42, 0.88, 0.52)
const WORSE_COLOR := Color(0.95, 0.42, 0.42)
const SAME_COLOR := Color(0.62, 0.66, 0.74)
const MINUS := "−"
## 조작성에서 계산하는 파생 스탯: ADS에 걸리는 시간(초).
const ADS_TIME := &"ads_time"


## 표시할 스탯 한 줄의 정의.
class Row:
	var key: StringName
	var label: String
	var lower_is_better: bool
	var decimals: int
	var suffix: String
	## 화면 값 = 저장 값 + display_offset (배율은 1 + zoom으로 보인다).
	var display_offset: float

	func _init(p_key: StringName, p_label: String, p_lower_is_better: bool, p_decimals: int,
			p_suffix: String = "", p_display_offset: float = 0.0) -> void:
		key = p_key
		label = p_label
		lower_is_better = p_lower_is_better
		decimals = p_decimals
		suffix = p_suffix
		display_offset = p_display_offset


## 장착/분리를 미리 계산한 결과. error가 비어 있으면 stats와 size가 유효하다.
class Preview:
	var error: StringName = &""
	var stats: Dictionary[StringName, float] = {}
	var size: Vector2i = Vector2i.ZERO


static func rows() -> Array[Row]:
	return [
		Row.new(WeaponStats.RECOIL, "반동", true, 1),
		Row.new(WeaponStats.ERGONOMICS, "조작성", false, 1),
		Row.new(ADS_TIME, "조준 시간", true, 2, " s"),
		Row.new(WeaponStats.SPREAD, "퍼짐", true, 2, "°"),
		Row.new(WeaponStats.WEIGHT, "무게", true, 2, " kg"),
		Row.new(WeaponStats.LOUDNESS, "소음", true, 2, "×"),
		Row.new(WeaponStats.RANGE, "사거리", false, 0, " m"),
		Row.new(WeaponMotion.ZOOM, "배율", false, 1, "x", 1.0),
	]


## 현재 부품 구성의 스탯 (없는 키는 0, 소음은 1.0).
static func current(assembly: WeaponAssembly) -> Dictionary[StringName, float]:
	var stats: Dictionary[StringName, float] = assembly.compute_stats()
	for row: Row in rows():
		if not stats.has(row.key):
			stats[row.key] = 1.0 if row.key == WeaponStats.LOUDNESS else 0.0
	stats[ADS_TIME] = WeaponMotion.ads_time_for(stats.get(WeaponStats.ERGONOMICS, 0.0))
	return stats


## 변화 old → new가 표시 자릿수에서 달라 보이는지, 좋은 쪽인지.
static func verdict(row: Row, old_value: float, new_value: float) -> Verdict:
	var step: float = 0.5 * pow(10.0, -float(row.decimals))
	var diff: float = new_value - old_value
	if absf(diff) < step:
		return Verdict.SAME
	var improved: bool = diff < 0.0 if row.lower_is_better else diff > 0.0
	return Verdict.BETTER if improved else Verdict.WORSE


static func verdict_color(v: Verdict) -> Color:
	match v:
		Verdict.BETTER:
			return BETTER_COLOR
		Verdict.WORSE:
			return WORSE_COLOR
	return SAME_COLOR


static func format_value(row: Row, value: float) -> String:
	return ("%." + str(row.decimals) + "f") % (value + row.display_offset) + row.suffix


## "+4.0" / "−0.30" 같은 변화량 글자 (같으면 빈 문자열).
static func format_delta(row: Row, old_value: float, new_value: float) -> String:
	if verdict(row, old_value, new_value) == Verdict.SAME:
		return ""
	var diff: float = new_value - old_value
	return ("+" if diff > 0.0 else MINUS) + ("%." + str(row.decimals) + "f") % absf(diff)


## 소켓에 부품을 달았을 때의 스탯·크기를 계산한다. 트리를 잠깐 바꿨다가 정확히 되돌리므로 호출 전후 상태는 같다.
static func preview_attach(weapon: ItemInstance, parent_path: Array[StringName], socket_name: StringName,
		part: WeaponPartDef) -> Preview:
	var result := Preview.new()
	var assembly: WeaponAssembly = weapon.weapon
	var node := WeaponPartNode.new(part)
	result.error = assembly.attach_node(parent_path, socket_name, node)
	if result.error != WeaponAssembly.OK:
		return result
	result.stats = current(assembly)
	result.size = weapon.size_for(weapon.rotated)
	assembly.detach(parent_path, socket_name)
	return result


## 소켓의 부품을 뗐을 때의 스탯·크기. 아래에 부품이 달려 있으면 HAS_ATTACHMENTS.
static func preview_detach(weapon: ItemInstance, parent_path: Array[StringName],
		socket_name: StringName) -> Preview:
	var result := Preview.new()
	var assembly: WeaponAssembly = weapon.weapon
	var path: Array[StringName] = parent_path.duplicate()
	path.append(socket_name)
	var node: WeaponPartNode = assembly.find_node(path)
	if node == null:
		result.error = WeaponAssembly.UNKNOWN_SOCKET
		return result
	if not node.children.is_empty():
		result.error = CommandResult.HAS_ATTACHMENTS
		return result
	assembly.detach(parent_path, socket_name)
	result.stats = current(assembly)
	result.size = weapon.size_for(weapon.rotated)
	assembly.attach_node(parent_path, socket_name, node)
	return result


## 부품 하나가 주는 효과를 한 줄로 ("반동 −4 · 조작성 +1 · 가로 +1칸"). 후보 목록 둘째 줄에 쓴다.
static func part_summary(def: WeaponPartDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row: Row in rows():
		if def.modifiers != null and def.modifiers.additive.has(row.key):
			var value: float = def.modifiers.additive[row.key]
			if verdict(row, 0.0, value) != Verdict.SAME:
				parts.append("%s %s%s" % [row.label, "+" if value > 0.0 else MINUS, _trim(absf(value), row.decimals)])
		if def.modifiers != null and def.modifiers.multiplier.has(row.key):
			parts.append("%s ×%s" % [row.label, _trim(def.modifiers.multiplier[row.key], 2)])
	if def.size_delta.x != 0:
		parts.append("가로 %s%d칸" % ["+" if def.size_delta.x > 0 else MINUS, absi(def.size_delta.x)])
	if def.size_delta.y != 0:
		parts.append("세로 %s%d칸" % ["+" if def.size_delta.y > 0 else MINUS, absi(def.size_delta.y)])
	return " · ".join(parts) if not parts.is_empty() else "변화 없음"


## 소수 끝의 0을 지운 숫자 글자 (2.50 → "2.5", 3.00 → "3").
static func _trim(value: float, decimals: int) -> String:
	var text: String = ("%." + str(decimals) + "f") % value
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text
