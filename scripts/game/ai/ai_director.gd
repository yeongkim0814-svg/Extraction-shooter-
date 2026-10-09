class_name AiDirector
extends Node
## 적 AI 감독 (M8): 살아 있는 적 목록을 갖고, 소음(총소리·발소리)을 반경 안의 적에게 전달한다.

## 플레이어 총소리를 냈다 (반경 m). 로그·HUD용.
signal player_shot_noise(radius: float)

const FOOTSTEP_INTERVAL: float = 0.4

var enemies: Array[EnemyAgent] = []

var _player: PlayerController
var _footstep_timer: float = 0.0


func register(enemy: EnemyAgent) -> void:
	if not enemies.has(enemy):
		enemies.append(enemy)


## 플레이어의 총소리·발소리를 감독에 연결한다.
func bind_player(player: PlayerController) -> void:
	_player = player
	player.weapons.shot_fired.connect(_on_player_shot)


## 소음을 낸다: 반경 안(청각 배율 반영)의 살아 있는 적에게 전달한다. source 본인은 제외.
func report_noise(position_: Vector3, radius: float, source: Node) -> void:
	if radius <= 0.0:
		return
	for enemy: EnemyAgent in enemies:
		if enemy == source or enemy.is_dead() or enemy.profile == null:
			continue
		if AiPerception.hears(position_, radius, enemy.global_position, enemy.profile.hearing_mult):
			enemy.hear_noise(position_)


func living_enemies() -> Array[EnemyAgent]:
	var result: Array[EnemyAgent] = []
	for enemy: EnemyAgent in enemies:
		if not enemy.is_dead():
			result.append(enemy)
	return result


## 위치에서 가장 가까운 살아 있는 적. 없으면 null.
func nearest_living(position_: Vector3) -> EnemyAgent:
	var best: EnemyAgent = null
	var best_dist: float = INF
	for enemy: EnemyAgent in living_enemies():
		var dist: float = enemy.global_position.distance_to(position_)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _on_player_shot(_ammo_id: StringName, _rounds_left: int) -> void:
	var runtime: WeaponRuntime = _player.weapons.current_runtime()
	var loudness: float = runtime.stats.get(WeaponStats.LOUDNESS, 1.0) if runtime != null else 1.0
	var radius: float = AiPerception.shot_noise_radius(loudness)
	report_noise(_player.global_position, radius, _player)
	player_shot_noise.emit(radius)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	_footstep_timer = FOOTSTEP_INTERVAL
	if _player.health.is_dead():
		return
	var moving: bool = _player.move_speed_ratio() > 0.1
	var radius: float = AiPerception.footstep_noise_radius(_player.is_sprinting(), _player.is_crouching(), moving)
	report_noise(_player.global_position, radius, _player)
