# 기술 아키텍처

## 1. 스택

- **Godot 4.4.x** (stable 고정, 사용자·컨테이너·CI 모두 같은 버전)
- 언어: **GDScript, 정적 타입 강제** (`debug/gdscript/warnings/untyped_declaration = error`)
  - C#을 쓰지 않는 이유: Godot 4의 C# 프로젝트는 웹 내보내기를 지원하지 않음
- 렌더러: Android = **Mobile**, 웹 = **Compatibility** (웹은 Compatibility만 지원)
- 테스트: **GUT** (Godot Unit Test) 애드온, 헤드리스 실행
- 데이터: 커스텀 `Resource` 클래스 + `.tres` 텍스트 파일
- 멀티(후속): Godot 고수준 멀티플레이 API, 네이티브는 ENet, 웹은 WebSocket/WebRTC, 헤드리스 데디케이티드 서버

## 2. 작업 흐름 (태블릿 + 클라우드)

| | 사용자 (갤럭시 탭, Godot 안드로이드 에디터) | Claude (클라우드 컨테이너, 헤드리스 Godot) |
|---|---|---|
| 작성 | 씬 배치, 레벨 그레이박스, 머티리얼 조정, 모델 임포트 | 코드, 데이터(`.tres`), 씬 파일(`.tscn`), 테스트 |
| 검증 | 탭에서 직접 플레이 (터치 조작감·체감 성능) | GUT 자동 테스트, 웹 빌드를 Chromium에서 실행해 스크린샷·콘솔 확인 |
| 동기화 | Git (탭: Termux 또는 Git 클라이언트 앱) | Git |

- `.tscn`·`.tres`·`project.godot`은 텍스트라 Git diff·병합 가능. 같은 씬을 양쪽에서 동시에 편집하지 않는다 (씬 단위로 작업 분담)
- `.godot/` 폴더(임포트 캐시)는 커밋하지 않는다

## 3. 플랫폼 제약이 만드는 규칙

| 제약 | 규칙 |
|---|---|
| 웹 스레드 | 단일 스레드 웹 내보내기 사용 (SharedArrayBuffer 불필요 → 일반 웹호스팅·itch.io 배포 가능). 코어에서 `Thread` 사용 금지 |
| 웹 렌더러 | Compatibility 기능 범위 안에서 그래픽 설계 ([ART.md](ART.md)) |
| 저장 | `user://` 경로 사용 (웹은 IndexedDB, Android는 앱 저장소로 자동 매핑) |
| 다운로드 크기 | 맵·무기 에셋을 추가 `.pck`로 분리, `HTTPRequest`로 받아 `ProjectSettings.load_resource_pack`으로 로드. 웹 초기 다운로드 ≤50MB 목표 |
| 메모리 | 모바일 웹 최하위 티어, 텍스처 압축 ETC2/ASTC(모바일)·S3TC(데스크톱 웹) |
| GC 없음, 할당 비용 | GDScript는 참조 카운팅. 매 프레임 `Array`·`Dictionary` 생성 금지, 그리드 점유맵은 `PackedInt32Array` |

## 4. 레이어

```
core/   (RefCounted 기반 순수 로직. Node·씬 트리 의존 금지 → 헤드리스 테스트 가능)
  items · inventory · equipment · weapons · search · raid · loot · ai_decision · save · commands
   ▲ 호출만
game/   (Node 어댑터: core 호출 + 씬 연결)
  player · weapon_view · ai_agent(NavigationAgent3D·감지) · loot_container · extraction_zone
ui/     (Control 노드: 인벤토리 · 수색 · HUD · 메뉴 · 터치 컨트롤)
net/    (후속: 서버 권한)
```

- core는 씬 트리를 모른다. game/ui는 core의 시그널(이벤트)을 받아 화면을 갱신한다
- 인벤토리 드래그앤드롭은 Control의 내장 `_get_drag_data` / `_can_drop_data` / `_drop_data` 사용. 터치는 `emulate_mouse_from_touch`로 같은 경로를 탄다

## 5. 멀티플레이 대비 규칙 (PvE 단계부터 적용)

- 모든 상태 변경은 `Command → GameAuthority.execute() → CommandResult + 이벤트 목록`
  - 지금은 `LocalAuthority`, 멀티 단계에서 서버 권한(RPC로 Command 전송, 서버만 실행)으로 교체
- 아이템 인스턴스 ID는 권한자가 발급 (`IdGenerator`), 클라이언트 생성 금지 → 거래소 복제 방지의 기반
- 난수는 시드 주입 (`RandomNumberGenerator`를 주입) → 루팅·AI 판단 재현 가능, 테스트 결정적
- 시뮬레이션(데미지·탄도 판정·수색 시간)은 core에 두어 서버에서 동일 코드 실행

## 6. 저장소 구조

```
project.godot
export_presets.cfg          # Web, Android 프리셋
addons/gut/                 # 테스트 프레임워크
scripts/
  core/  items/ inventory/ equipment/ weapons/ search/ raid/ loot/ ai_decision/ save/ commands/
  game/  ui/  net/(후속)
data/                       # .tres: 아이템·무기 부품·루팅 테이블·AI 프로필
scenes/                     # .tscn: 맵·플레이어·무기·UI
assets/
  models/ textures/ materials/ shaders/ audio/ fonts/
tests/
  unit/                     # core 단위 테스트 (GUT)
  integration/              # 씬 로드·노드 연결 테스트 (헤드리스)
tools/                      # 컨테이너용 스크립트: Godot 설치, 웹 빌드, 스크린샷
docs/
.github/workflows/tests.yml
```

## 7. core 모듈 설계

### items
- `ItemDef` (Resource): id, 이름, `width`×`height`, `max_stack`, `can_rotate`, 카테고리, 무게, `base_price`, `tradeable`, 효과 목록(`ItemEffect` 리소스 배열: 지혈·회복·진통·버프 조합)
- `ItemInstance`: 권한자 발급 id, def, `stack_count`, 위치, `rotated`, `found_in_raid`, (컨테이너형이면) 내부 그리드

### inventory
- `GridContainer` (core 클래스, UI의 Control `GridContainer`와 이름 충돌 피하려 `ItemGrid`로 명명): `PackedInt32Array` 점유맵 + 아이템 목록
- 점유 크기: `rotated ? (h, w) : (w, h)`
- 연산: `can_place` / `try_place` / `remove` / `move`(같은 그리드 내 이동은 자기 자신 무시, 원자적) / `try_auto_place`(행 우선, 두 방향 시도) / `merge` / `split`
- 그리드 간 이동: 목적지 실패 시 원위치 복구 (롤백)
- 중첩 규칙: 배낭 안 배낭 금지, 자기 자신 안으로 넣기 금지
- 불변식: 점유맵 = 아이템 목록에서 재계산한 맵 (고정 시드 무작위 테스트로 검증)

### equipment
- `EquipmentSlots`: 슬롯별 허용 카테고리 검증, 장착 시 리그·배낭 그리드 제공

### weapons
- `WeaponPartDef` (Resource): 자식 소켓 목록, 스탯 수정치(가산·배율), 크기 기여분, 모델 씬 경로
- `WeaponAssembly`: 부품 트리
- `CompatibilityRules`: 소켓 타입 + 허용 목록 + 충돌 규칙
- `StatCalculator`: 트리 전체 합산 → 반동·인체공학·무게·정확도·소음
- `AssemblySize`: 부품 구성에 따른 인벤토리 크기
- `Magazine`: 탄을 담는 컨테이너
- `DamageModel`: 탄 관통력 vs 방탄 등급

### search
- `SearchState`: 컨테이너별 공개 진행도
- `SearchTimeCalculator`: 기본값 × 크기·희귀도 계수
- 중단·재개 규칙, 수색 소음 이벤트 발행

### raid
- `RaidSession` 상태머신: Hideout → Loadout → Raid → Extracted | Dead → Results
- `ExtractionRule`, `DeathResolver`(보안 컨테이너 보존), `RaidResultTransfer`(스태시 부족 시 소실 경고)

### loot
- `LootTable` (Resource): 가중치 기반, 시드 고정

### ai_decision
- 블랙보드 + 상태 전이 규칙 (순찰·의심·교전·엄폐·수색·복귀) → 헤드리스 테스트
- 감지(레이캐스트·시야각)·이동(`NavigationAgent3D`)은 game 레이어

### save
- 저장 데이터는 Dictionary DTO + `version` 필드 + 마이그레이션 체인, `JSON`으로 직렬화해 `user://`에 기록

## 8. 테스트·빌드

- 단위 테스트: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
  - 인벤토리 엣지케이스: 경계에 딱 맞는 배치, 1×1 틈 채우기, 회전해야만 들어가는 경우, 가득 찬 그리드, 제거 후 재배치, 스택 병합 잔량 분할, 직렬화 왕복 후 점유맵 동일성
- 통합 테스트: 씬을 헤드리스로 로드해 노드 연결·시그널 배선 확인
- 웹 스모크 테스트: 웹 내보내기 → 로컬 서버 → Playwright(Chromium)로 실행, 콘솔 에러 0 확인 + 스크린샷
- CI: PR마다 GitHub Actions에서 헤드리스 Godot으로 GUT 실행
- 수동: 마일스톤별 탭 체크리스트(터치 조작감·프레임)를 `docs/`에 둠

## 9. 성능 예산 (코드 측)

[ART.md](ART.md)의 폴리곤·텍스처 예산과 품질 티어를 따른다.
- 매 프레임 할당 최소화 (Godot 프로파일러로 확인)
- AI 감지는 프레임 분산 (에이전트별 주기 갱신)
- 물리 레이캐스트는 충돌 레이어·마스크 필수
- 핫패스는 정적 타입 GDScript로 작성 (타입 지정 시 실행 속도 향상)
