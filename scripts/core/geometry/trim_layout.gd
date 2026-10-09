class_name TrimLayout
extends RefCounted
## 스타일 D 트림시트의 줄(strip) 배치. tools/gen_trim_sheets.py가 만드는 두 시트(1024 x 1024)의 가로 띠 위치와 같은 값이다
## (assets/textures/trim/trim_layout.json과 테스트가 맞춰 본다). 순수 데이터라 노드·씬 트리에 의존하지 않는다.
## 시트 1 = 콘크리트·벽돌, 시트 2 = 금속·컨테이너. U는 가로로 이어 붙고, V는 줄의 세로 범위가 된다.

const SIZE: int = 1024
## 텍스처 밀도: 1 m당 256 텍셀이라 U 한 바퀴(1024 px)가 실제 4 m다.
const TEXELS_PER_M: float = 256.0
const TILE_M: float = float(SIZE) / TEXELS_PER_M

const SHEET_CONCRETE: int = 1
const SHEET_METAL: int = 2

## 줄 이름. 시트 1.
const WALL: StringName = &"wall"
const PANEL: StringName = &"panel"
const BRICK: StringName = &"brick"
const BAND: StringName = &"band"
const HAZARD: StringName = &"hazard"
const EDGE_TRIM: StringName = &"edge_trim"
const WINDOW: StringName = &"window"
const VENT: StringName = &"vent"
## 줄 이름. 시트 2.
const CORRUGATED: StringName = &"corrugated"
const PLATE: StringName = &"plate"
const CHIPPED: StringName = &"chipped"
const RUST: StringName = &"rust"
const GRATE: StringName = &"grate"
const PIPE: StringName = &"pipe"
const HINGE: StringName = &"hinge"
const LABEL: StringName = &"label"

## 시트별 줄: 이름 -> (시작 y px, 높이 px).
const STRIPS: Dictionary[int, Dictionary] = {
	1: {
		&"wall": Vector2i(4, 176), &"panel": Vector2i(188, 188), &"brick": Vector2i(384, 156), &"band": Vector2i(548, 88),
		&"hazard": Vector2i(644, 64), &"edge_trim": Vector2i(716, 48), &"window": Vector2i(772, 144), &"vent": Vector2i(924, 96),
	},
	2: {
		&"corrugated": Vector2i(4, 184), &"plate": Vector2i(196, 152), &"chipped": Vector2i(356, 128), &"rust": Vector2i(492, 112),
		&"grate": Vector2i(612, 128), &"pipe": Vector2i(748, 96), &"hinge": Vector2i(852, 96), &"label": Vector2i(956, 64),
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


## 줄의 자연 높이 (m): 텍셀 밀도 그대로 붙였을 때의 세로 길이. 면이 이보다 훨씬 높으면 소품 코드가 면을 쌓아 나눈다.
static func strip_height_m(sheet: int, strip_name: StringName) -> float:
	var table: Dictionary = STRIPS.get(sheet, {})
	if not table.has(strip_name):
		return float(SIZE) / TEXELS_PER_M
	return float((table[strip_name] as Vector2i).y) / TEXELS_PER_M
