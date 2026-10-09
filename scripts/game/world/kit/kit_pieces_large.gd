class_name KitPiecesLarge
extends RefCounted
## 대형 부품 (탱크·배관 랙·컨테이너·차량 등). 원점 = 바닥 중심.


static func build(piece: StringName, _kb: KitBuild) -> bool:
	match piece:
		_:
			return false
