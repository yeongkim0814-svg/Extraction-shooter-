class_name KitLayout
extends RefCounted
## 텍스처 v2 트림시트의 줄(strip) 배치. tools/gen_textures_v2.py가 만드는 세 시트(1024 x 1024)의 가로 띠 위치와 같은 값이다
## (assets/textures/v2/kit_layout.json과 테스트가 맞춰 본다). 순수 데이터라 노드·씬 트리에 의존하지 않는다.
## 시트 1 = 구조, 시트 2 = 금속, 시트 3 = 설비. U는 가로로 이어 붙고(4 m), V는 줄의 세로 범위가 된다.

const SIZE: int = 1024
## 텍스처 밀도: 1 m당 256 텍셀이라 U 한 바퀴(1024 px)가 실제 4 m다.
const TEXELS_PER_M: float = 256.0
const TILE_M: float = float(SIZE) / TEXELS_PER_M

const SHEET_STRUCTURE: int = 1
const SHEET_METAL: int = 2
const SHEET_FIXTURES: int = 3

## 줄 이름. 시트 1 (구조).
const WALL: StringName = &"wall"
const PANEL: StringName = &"panel"
const BRICK: StringName = &"brick"
const BAND: StringName = &"band"
const HAZARD: StringName = &"hazard"
const WINDOW: StringName = &"window"
const SHUTTER: StringName = &"shutter"
const SILL: StringName = &"sill"
## 줄 이름. 시트 2 (금속).
const CORRUGATED: StringName = &"corrugated"
const PLATE: StringName = &"plate"
const CHIPPED: StringName = &"chipped"
const RUST: StringName = &"rust"
const GRATE: StringName = &"grate"
const PIPE: StringName = &"pipe"
const BEAM: StringName = &"beam"
const TREAD: StringName = &"tread"
## 줄 이름. 시트 3 (설비).
const VENT: StringName = &"vent"
const PIPE_JOINT: StringName = &"pipe_joint"
const CABLE: StringName = &"cable"
const CABINET: StringName = &"cabinet"
const SIGN: StringName = &"sign"
const FLUORO: StringName = &"fluoro"
const DOOR_HW: StringName = &"door_hw"
const DUCT: StringName = &"duct"

## 시트별 줄: 이름 -> (시작 y px, 높이 px).
const STRIPS: Dictionary[int, Dictionary] = {
	1: {
		&"wall": Vector2i(4, 160), &"panel": Vector2i(172, 176), &"brick": Vector2i(356, 144), &"band": Vector2i(508, 80),
		&"hazard": Vector2i(596, 56), &"window": Vector2i(660, 136), &"shutter": Vector2i(804, 136), &"sill": Vector2i(948, 48),
	},
	2: {
		&"corrugated": Vector2i(4, 176), &"plate": Vector2i(188, 144), &"chipped": Vector2i(340, 120), &"rust": Vector2i(468, 112),
		&"grate": Vector2i(588, 120), &"pipe": Vector2i(716, 96), &"beam": Vector2i(820, 96), &"tread": Vector2i(924, 96),
	},
	3: {
		&"vent": Vector2i(4, 128), &"pipe_joint": Vector2i(140, 96), &"cable": Vector2i(244, 80), &"cabinet": Vector2i(332, 160),
		&"sign": Vector2i(500, 96), &"fluoro": Vector2i(604, 64), &"door_hw": Vector2i(676, 128), &"duct": Vector2i(812, 128),
	},
}


## 줄의 V 범위 (x = 위쪽 v0, y = 아래쪽 v1). 없는 줄이면 시트 전체.
static func v_range(sheet: int, strip_name: StringName) -> Vector2:
	var table: Dictionary = STRIPS.get(sheet, {})
	if not table.has(strip_name):
		return Vector2(0.0, 1.0)
	var span: Vector2i = table[strip_name]
	return Vector2(float(span.x) / float(SIZE), float(span.x + span.y) / float(SIZE))


static func has_strip(sheet: int, strip_name: StringName) -> bool:
	return (STRIPS.get(sheet, {}) as Dictionary).has(strip_name)


## 줄의 자연 높이 (m): 텍셀 밀도 그대로 붙였을 때의 세로 길이.
static func strip_height_m(sheet: int, strip_name: StringName) -> float:
	var table: Dictionary = STRIPS.get(sheet, {})
	if not table.has(strip_name):
		return float(SIZE) / TEXELS_PER_M
	return float((table[strip_name] as Vector2i).y) / TEXELS_PER_M
