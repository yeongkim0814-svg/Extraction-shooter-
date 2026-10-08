# Extraction Shooter

Godot 4.4 기반 모바일/웹 탈출 슈터 프로젝트. 핵심 로직은 `scripts/core/`의 순수 GDScript(RefCounted)로 두고 GUT로 테스트한다.

## 탭(Android)에서 열기
1. Godot 4.4.x Android 에디터를 설치한다.
2. 저장소를 clone한다 (에셋은 Git LFS 사용).
3. 에디터에서 `project.godot`을 Import 한다.

## 테스트 실행
```
tools/run_tests.sh
```
Godot 4.4.1을 `~/.local/godot/`에 자동 설치(`tools/install_godot.sh`)한 뒤 헤드리스로 GUT를 실행한다. 다른 바이너리는 `GODOT` 환경변수로 지정.

## 문서
- [로드맵](docs/PLAN.md)
- [GDD](docs/GDD.md)
- [아트](docs/ART.md)
- [기술 아키텍처](docs/TECH.md)
