class_name SaveMigrations
extends RefCounted
## 저장 데이터 버전 마이그레이션 체인. 새 버전을 추가하려면
##   1) CURRENT_VERSION을 올리고  2) `_migrate_v1_to_v2` 같은 함수를 만들고  3) `_step`의 match에 한 줄 추가한다.
## 각 단계는 데이터를 받아 "version"이 한 단계 올라간 새 Dictionary를 돌려준다.

const CURRENT_VERSION := 1


## 저장 데이터의 version을 정수로 (없거나 숫자가 아니면 0).
static func version_of(data: Dictionary) -> int:
	var raw: Variant = data.get("version")
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return int(raw)
	return 0


## 오래된 데이터를 CURRENT_VERSION까지 끌어올린다. 입력은 바꾸지 않고, 적용할 단계가 없거나
## 이미 최신/더 새로운 버전이면 그대로(복사본) 돌려준다. 판정(거부)은 호출자가 한다.
static func migrate(data: Dictionary) -> Dictionary:
	var current: Dictionary = data.duplicate(true)
	var version: int = version_of(current)
	while version >= 1 and version < CURRENT_VERSION:
		var migrated: Dictionary = _step(version, current)
		var next_version: int = version_of(migrated)
		if next_version <= version:  # 단계가 없거나 버전을 올리지 못함: 무한 루프 방지
			break
		current = migrated
		version = next_version
	return current


static func _step(from_version: int, data: Dictionary) -> Dictionary:
	match from_version:
		# 1: return _migrate_v1_to_v2(data)
		_:
			return data


# 예시 (v2 도입 시):
# static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
# 	var result: Dictionary = data.duplicate(true)
# 	result["version"] = 2
# 	return result
