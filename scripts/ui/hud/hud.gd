class_name Hud
extends Control
## 전투 HUD: 조준선(ADS 중 숨김), 탄약 "현재/용량" + 무기 이름 + 휴대 탄약, 체력 바, 재장전 진행, 알림 한 줄.
## 전부 _draw로 그린다 (글자는 프로젝트 기본 폰트 = 한글 지원).

const CROSSHAIR_COLOR := Color(0.95, 1.0, 0.95, 0.9)
const CROSSHAIR_GAP: float = 7.0
const CROSSHAIR_LEN: float = 11.0
const HIT_MARKER_TIME: float = 0.18
const DRY_FLASH_TIME: float = 0.35
const TOAST_TIME: float = 2.0
const BAR_BG := Color(0.05, 0.06, 0.08, 0.6)
const MARGIN: float = 24.0

var _player: PlayerController
var _weapons: WeaponController
var _authority: GameAuthority
var _carried: int = 0
var _toast_text: String = ""
var _toast_left: float = 0.0
var _hint_text: String = ""
var _hit_left: float = 0.0
var _hit_penetrated: bool = true
var _dry_left: float = 0.0
var _ads: bool = false
var _ammo_box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_box = StyleBoxFlat.new()
	_ammo_box.bg_color = Color(0.09, 0.1, 0.13, 0.55)
	_ammo_box.border_color = Color(InventoryStyle.PANEL_BORDER, 0.8)
	_ammo_box.set_border_width_all(2)
	_ammo_box.set_corner_radius_all(8)


func bind(player: PlayerController, weapons: WeaponController, authority: GameAuthority) -> void:
	_player = player
	_weapons = weapons
	_authority = authority
	weapons.weapon_changed.connect(_refresh_carried)
	weapons.shot_fired.connect(func(_ammo_id: StringName, _rounds: int) -> void: queue_redraw())
	weapons.reload_finished.connect(func(_ok: bool, _error: StringName) -> void: _refresh_carried())
	weapons.toast.connect(show_toast)
	weapons.dry_fired.connect(func() -> void: _dry_left = DRY_FLASH_TIME)
	weapons.hit_registered.connect(func(_t: HitTarget, result: DamageModel.HitResult) -> void:
		_hit_left = HIT_MARKER_TIME
		_hit_penetrated = result.penetrated)
	player.ads_changed.connect(func(on: bool) -> void: _ads = on)
	authority.events_emitted.connect(func(_events: Array[DomainEvent]) -> void: _refresh_carried())
	_refresh_carried()


func show_toast(text: String) -> void:
	_toast_text = text
	_toast_left = TOAST_TIME


## 화면 위쪽 안내 문구 (빈 문자열이면 숨김).
func set_hint(text: String) -> void:
	_hint_text = text


func toast_text() -> String:
	return _toast_text if _toast_left > 0.0 else ""


func _refresh_carried() -> void:
	var runtime: WeaponRuntime = _weapons.current_runtime() if _weapons != null else null
	if runtime == null:
		_carried = 0
	else:
		_carried = AmmoCounter.count_carried(
				_authority.inventory, _authority.content, runtime.item.magazine.caliber)
	queue_redraw()


func _process(delta: float) -> void:
	_toast_left = maxf(_toast_left - delta, 0.0)
	_hit_left = maxf(_hit_left - delta, 0.0)
	_dry_left = maxf(_dry_left - delta, 0.0)
	queue_redraw()


# --- 그리기 ---

func _draw() -> void:
	if _player == null:
		return
	var font: Font = get_theme_default_font()
	_draw_health(font)
	_draw_ammo(font)
	var center: Vector2 = size * 0.5
	if not _ads:
		_draw_crosshair(center)
	if _hit_left > 0.0:
		_draw_hit_marker(center)
	_draw_reload(font, center)
	if _toast_left > 0.0:
		_draw_banner(font, _toast_text, 64.0, 24)
	elif not _hint_text.is_empty():
		_draw_banner(font, _hint_text, 64.0, 20)


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(font, pos, text, align, width, font_size, 6, Color(0, 0, 0, 0.75))
	draw_string(font, pos, text, align, width, font_size, color)


func _draw_crosshair(center: Vector2) -> void:
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var from: Vector2 = center + dir * CROSSHAIR_GAP
		var to: Vector2 = center + dir * (CROSSHAIR_GAP + CROSSHAIR_LEN)
		draw_line(from, to, Color(0, 0, 0, 0.6), 5.0)
		draw_line(from, to, CROSSHAIR_COLOR, 2.5)
	draw_circle(center, 2.0, CROSSHAIR_COLOR)


func _draw_hit_marker(center: Vector2) -> void:
	var color: Color = Color(1, 1, 1, 0.95) if _hit_penetrated else Color(0.65, 0.7, 0.8, 0.95)
	for diag: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		draw_line(center + diag * 8.0, center + diag * 18.0, color, 3.0)
		draw_line(center - diag * 8.0, center - diag * 18.0, color, 3.0)


func _draw_health(font: Font) -> void:
	var h: Health = _player.health
	var rect := Rect2(MARGIN, MARGIN + 30.0, 280.0, 22.0)
	draw_rect(rect, BAR_BG)
	var ratio: float = clampf(h.hp / h.max_hp, 0.0, 1.0)
	var color: Color = Color(0.35, 0.8, 0.45).lerp(Color(0.9, 0.25, 0.2), 1.0 - ratio)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)
	draw_rect(rect, InventoryStyle.PANEL_BORDER, false, 2.0)
	_text(font, Vector2(MARGIN, MARGIN + 22.0), "체력  %d / %d" % [ceili(h.hp), int(h.max_hp)], 20, InventoryStyle.TEXT)
	if h.bleeding:
		_text(font, Vector2(MARGIN + 296.0, MARGIN + 48.0), "출혈", 20, Color(1.0, 0.35, 0.3))


func _draw_ammo(font: Font) -> void:
	var runtime: WeaponRuntime = _weapons.current_runtime()
	var panel := Rect2(size.x * 0.5 - 150.0, size.y - MARGIN - 92.0, 300.0, 92.0)
	draw_style_box(_ammo_box, panel)
	if runtime == null:
		_text(font, panel.position + Vector2(0, 54), "무기 없음", 24, InventoryStyle.TEXT_DIM,
				HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		return
	var mag: Magazine = runtime.item.magazine
	var name_text: String = "%d  %s" % [_weapons.current_index() + 1, runtime.item.def.display_name]
	_text(font, panel.position + Vector2(16, 28), name_text, 20, InventoryStyle.TEXT_DIM)
	var empty: bool = mag.count() == 0
	var ammo_color: Color = Color(1.0, 0.4, 0.35) if (empty or _dry_left > 0.0) else InventoryStyle.TEXT
	_text(font, panel.position + Vector2(16, 76), "%d / %d" % [mag.count(), mag.capacity], 40, ammo_color)
	_text(font, panel.position + Vector2(0, 76), "예비 %d" % _carried, 22, InventoryStyle.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 16.0)


func _draw_reload(font: Font, center: Vector2) -> void:
	var progress: float = _weapons.reload_progress()
	if progress < 0.0:
		return
	var rect := Rect2(center.x - 80.0, center.y + 44.0, 160.0, 10.0)
	draw_rect(rect, BAR_BG)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y)), Color(0.95, 0.8, 0.35))
	draw_rect(rect, InventoryStyle.PANEL_BORDER, false, 1.5)
	_text(font, Vector2(rect.position.x, rect.position.y + 34.0), "재장전 중", 20, InventoryStyle.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_banner(font: Font, text: String, y: float, font_size: int) -> void:
	_text(font, Vector2(0.0, y), text, font_size, Color(1.0, 0.92, 0.6), HORIZONTAL_ALIGNMENT_CENTER, size.x)
