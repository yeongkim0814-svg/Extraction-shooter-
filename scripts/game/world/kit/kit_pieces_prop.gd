class_name KitPiecesProp
extends RefCounted
## 소품 부품. 원점 = 바닥 중심.


static func build(piece: StringName, kb: KitBuild) -> bool:
	match piece:
		&"barrel":
			barrel(kb)
		&"lamp_sodium":
			lamp_sodium(kb)
		_:
			return false
	return true


## 200 L 드럼통 (지름 0.58 m, 높이 0.88 m): 둘레 감기 도장 + 테 두 줄 + 윗면 뚜껑.
static func barrel(kb: KitBuild) -> void:
	var r: float = 0.29
	var h: float = 0.88
	kb.cylinder(KitMaterials.METAL_CHIPPED, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)), r, h, 14, 0.02, false, false)
	for y: float in [h * 0.33, h * 0.66]:
		kb.cylinder(KitMaterials.METAL_CHIPPED, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)), r + 0.012, 0.03, 14, 0.0, false, false)
	kb.cylinder(KitMaterials.FLAT_METAL, Transform3D(Basis.IDENTITY, Vector3(0.12, h + 0.008, 0.08)), 0.03, 0.016, 8, 0.0, false, false)
	kb.collide_box(Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)), Vector3(r * 1.9, h, r * 1.9))


## 나트륨 갓 램프 (천장 매달기): 원점 = 천장 고정점, 아래로 매달린다. 빛 자리 LIGHT_sodium (전구 위치).
static func lamp_sodium(kb: KitBuild) -> void:
	kb.strut(KitMaterials.FLAT_METAL, Vector3.ZERO, Vector3(0.0, -0.9, 0.0), 0.025)
	kb.cylinder(KitMaterials.PIPE_TEAL, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.98, 0.0)), 0.07, 0.16, 10, 0.01, false, false)
	# 갓: 위가 좁고 아래가 넓은 원뿔대
	kb.use(KitMaterials.PIPE_TEAL)
	kb.mesh.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, -1.14, 0.0)), 0.32, 0.18, 16, 0.0, 0.1)
	kb.cylinder(KitMaterials.FLUORO_SODIUM, Transform3D(Basis.IDENTITY, Vector3(0.0, -1.2, 0.0)), 0.06, 0.08, 10, 0.0, false, false)
	kb.marker("LIGHT_sodium", Transform3D(Basis.IDENTITY, Vector3(0.0, -1.28, 0.0)))
