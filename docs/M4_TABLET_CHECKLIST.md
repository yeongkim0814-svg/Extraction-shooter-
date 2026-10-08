# M4 탭 검증 체크리스트 (Galaxy Tab + Godot 4.7.2 Android 에디터)

프로젝트 위치: `/storage/emulated/0/Extraction-shooter-`

## 0. 최신 코드 받기
1. Termux 열기 → `cd /storage/emulated/0/Extraction-shooter-`
2. `git pull` 실행 (오류가 나면 그 글자 그대로 캡처)

## 1. 테스트 씬 실행
1. Godot 에디터에서 프로젝트를 연다 (이미 열려 있으면 다시 불러오기).
2. 오른쪽 위 **Play(▶)** 버튼을 누른다. (메인 씬이 `platform_test`로 설정되어 있음)
3. 상자·기둥들 주위를 카메라가 천천히 도는지 확인한다.
4. 왼쪽 위 글자를 읽는다.
   - **FPS**: 10초 정도 보고 대략적인 숫자 (예: 55~60)
   - **Renderer**: `mobile` 이면 정상 (Android는 Mobile 렌더러). `gl_compatibility`면 그것도 알려줘.
   - **Adapter**: 그래픽 칩 이름 (예: Adreno, Mali)
5. **화면 전체를 스크린샷** 찍는다. 그림자·빛나는 기둥이 보이는지도 확인.
6. 에디터 아래쪽 **출력(Output)** 탭에 빨간 글씨(에러)가 있으면 캡처.

## 2. APK 내보내기 시도
실패해도 괜찮다. **메시지만 알려주면 된다.**
1. 메뉴 **Project > Export** 열기.
2. 왼쪽 목록에서 **Android** 선택.
3. 빨간 경고가 보이면(내보내기 템플릿 없음, 키스토어 없음, SDK 없음 등) 그대로 캡처.
4. 가능하면 **Export Project**를 눌러 결과(성공 / 에러 문구)를 캡처.

## 3. 라이트맵 베이크 테스트
1. `scenes/dev/platform_test.tscn`을 연다 (파일시스템 패널에서 더블탭).
2. 씬 트리 맨 위 노드 선택 → **+(노드 추가)** → `LightmapGI` 검색 → 추가.
3. 바닥·상자는 코드로 만들어지므로 베이크가 비어 있을 수 있다. 그래도 **Bake Lightmaps** 버튼(위쪽 툴바)을 눌러본다.
4. 결과 보고: 끝까지 됨 / 에러 문구 / 에디터가 멈춤·튕김 중 무엇인지, 걸린 시간.
5. 테스트가 끝나면 씬을 **저장하지 말고** 닫는다 (`git status`가 깨끗해야 함).

## 보내줄 것
- 오버레이가 보이는 스크린샷 (FPS·Renderer·Adapter)
- Export 화면 / 에러 문구 스크린샷
- 라이트맵 베이크 결과 (성공 or 에러 문구)
- 그 외 에러 텍스트 전부
