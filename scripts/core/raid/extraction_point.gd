class_name ExtractionPoint
extends Resource
## 탈출 지점 데이터.

@export var id: StringName = &""
## 안에서 버텨야 하는 시간 (초).
@export var wait_time: float = 7.0
## 비어 있으면 항상 열려 있다. 아니면 flags에 이 키가 true일 때만 열린다.
@export var required_flag: StringName = &""
