# Samsung Health Device Bridge

이 문서는 현재 브랜치 `feature/samsung-health-input-api` 에서 추가한 Android 브리지와 실기기 검증 흐름을 정리합니다.

목표는 다음 두 가지입니다.

1. 삼성 스마트폰의 Samsung Health 수면 데이터를 Android 앱에서 읽는다.
2. 읽은 데이터를 Jarvis 백엔드로 업로드해 웹과 오케스트레이터가 소비할 수 있는 형태로 정규화한다.

이 문서는 구현 세부보다 "팀원이 다시 따라 했을 때 바로 재현 가능한 실행 가이드"에 초점을 둡니다.

## 1. 현재 구현 범위

현재 브랜치에서 동작 확인한 범위는 다음과 같습니다.

- Android 앱에서 Samsung Health Data SDK 연결
- Samsung Health 개발자 모드 기준 `sleep read permission` 요청
- 최근 `n`일 수면 데이터 조회
- 수면 데이터를 백엔드 `POST /api/v1/health/sleep/bridge` 로 업로드
- 백엔드 `GET /api/v1/health/sleep` 에서 아래 필드 정규화
  - `wake_time`
  - `sleep_start`
  - `sleep_end`
  - `sleep_duration_minutes`
  - `average_sleep_duration_minutes`
  - `average_wake_time`
  - `sleep_history`
  - `today_sleep_recommendation`

실기기 검증에서는 최근 7일 범위 기준 `5건`의 sleep history 업로드를 확인했습니다.

## 2. 전체 구조

Samsung Health Data SDK는 서버에서 직접 호출하는 REST API가 아닙니다.

실제 구조는 다음과 같습니다.

1. Android 브리지 앱이 Samsung Health `HealthDataStore` 에 연결
2. 앱이 `sleep read permission` 을 요청
3. 앱이 최근 수면 데이터를 읽음
4. 앱이 데이터를 Jarvis 백엔드로 업로드
5. 백엔드가 최신 raw state 를 저장
6. 백엔드가 웹/브리핑에서 쓰기 쉬운 summary 형태로 정규화

즉, Samsung Health 는 "입력 계층"이고, Jarvis 백엔드는 "정규화 계층"입니다.

## 3. 관련 파일

### Android

- `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/MainActivity.kt`
  - 수동 업로드 UI
  - backend URL / bridge token 저장
  - auto sync 토글
- `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/SamsungHealthBridge.kt`
  - 수동 연결 / 권한 요청 / 업로드 진입점
- `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/SamsungHealthBridgeRepository.kt`
  - 수면 데이터 조회와 업로드 공용 로직
- `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/SamsungHealthAutoSyncWorker.kt`
  - WorkManager 기반 자동 동기화
- `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/BridgePreferences.kt`
  - URL, 토큰, 자동 동기화 상태, 마지막 업로드 wake time 저장
- `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/SamsungHealthSdkCompat.java`
  - SDK 메타데이터 / 접근 제한 우회용 compat helper

### Backend

- `backend/app/api/endpoints.py`
  - `GET /api/v1/health/sleep`
  - `POST /api/v1/health/sleep/bridge`
- `backend/app/services/samsung_health.py`
  - raw payload 정규화
  - 수면 이력 및 추천 문구 계산
- `backend/app/providers/samsung_health_state_provider.py`
  - 최신 업로드 payload 저장
- `backend/tests/test_samsung_health_api.py`
  - health summary 정규화 테스트

## 4. Android 브리지 준비

### 4.1 Samsung Health SDK 다운로드

Samsung Health Data SDK AAR 은 레포에 포함하지 않습니다.

각 개발자는 Samsung Developer 에서 SDK 를 직접 내려받아 아래 위치에 넣어야 합니다.

```text
android-bridge/app/libs/samsung-health-data-api-1.1.0.aar
```

레포에는 빈 디렉터리 유지를 위한 `.gitkeep` 만 포함되어 있습니다.

### 4.2 Android Studio 실행

1. `ABS-Project-Jarvis/android-bridge/` 를 Android Studio 로 연다.
2. Gradle Sync 를 마친다.
3. 삼성폰을 USB 디버깅으로 연결해 `Run` 한다.

초기 설치 후에는 USB 없이 폰에서 앱을 다시 실행할 수 있습니다.

## 5. Samsung Health 개발자 모드

현재 구현은 "개발자 모드 기반 read 테스트"를 전제로 합니다.

삼성헬스 앱에서 아래를 켭니다.

1. Samsung Health 실행
2. `Settings > About Samsung Health`
3. 버전 줄을 여러 번 탭
4. `Developer mode (Samsung Health Data SDK)` 진입
5. `Developer mode for data read` 를 `ON`

참고:

- `Developer mode for data write` 는 현재 범위에서 필요하지 않습니다.
- write 는 "앱에서 Samsung Health 로 데이터를 쓰는 경우"에만 필요합니다.

## 6. 백엔드 환경변수

현재 브리지 흐름에 필요한 최소 환경변수는 아래와 같습니다.

```env
SAMSUNG_HEALTH_USE_MOCK=false
SAMSUNG_HEALTH_BRIDGE_TOKEN=replace-me-123
SAMSUNG_HEALTH_STATE_PATH=/tmp/jarvis-samsung-health-state.json
```

설명:

- `SAMSUNG_HEALTH_USE_MOCK=false`
  - `/api/v1/health/sleep`가 mock 대신 업로드된 실데이터를 읽게 함
- `SAMSUNG_HEALTH_BRIDGE_TOKEN`
  - Android 브리지 앱이 업로드할 때 사용하는 인증 토큰
- `SAMSUNG_HEALTH_STATE_PATH`
  - 최신 raw payload 저장 위치

## 7. 가장 빠른 실기기 테스트

### 7.1 맥북에서 백엔드 실행

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 7.2 폰과 네트워크 조건

- 폰과 맥북이 같은 Wi-Fi 에 있어야 합니다.
- 백엔드 주소는 아래 둘 중 하나를 사용합니다.
  - 로컬 IP 예: `http://192.168.0.109:8000`
  - Bonjour 주소 예: `http://baemingyuui-MacBookAir.local:8000`

현재 Android 브리지 기본값은 `.local` 주소를 쓰도록 되어 있습니다.

### 7.3 앱에서 실행

1. `Connect Samsung Health`
2. `Request Sleep Permission`
3. 수면 데이터 읽기 권한 팝업 허용
4. `Read Last 7 Days and Upload`
5. 백엔드 확인

```bash
curl http://localhost:8000/api/v1/health/sleep
```

## 8. 최근 7일이 1건만 보일 때

이 브랜치 초기에 "최근 7일인데 1건만 업로드되는" 문제가 있었습니다.

원인은 다음과 같았습니다.

- sleep data 가 하루 단위 포인트로 저장될 수 있는데
- 단일 `InstantTimeFilter` 기반 조회에서는 원하는 범위가 충분히 잡히지 않았습니다.

현재는 아래 방식으로 수정했습니다.

- 최근 `n`일을 날짜별 `LocalTimeFilter` 로 조회
- 조회 결과를 하나의 payload 로 합침
- `start_time-end_time` 기준으로 중복 제거

이후 실기기에서 최근 5건 수면 이력을 정상적으로 업로드하는 것을 확인했습니다.

## 9. 자동 실행 초안

이 브랜치에는 "기상 직후 비서 실행"을 목표로 한 auto sync 초안도 포함되어 있습니다.

구조는 다음과 같습니다.

1. 앱에서 `Enable automatic wake-time sync` 체크
2. WorkManager 가 대략 15분마다 실행
3. 최근 수면 데이터를 읽음
4. 가장 최근 `wake_time` 이 마지막 업로드 값보다 새로우면 업로드
5. 백엔드는 최신 sleep summary 를 갱신

제약:

- 안드로이드 백그라운드 정책 때문에 "완전 실시간"은 아닙니다.
- 현재 구현은 "약 15분 내외 반자동 감지"에 가깝습니다.
- 그래도 기상 후 바로 비서가 실행되도록 확장할 수 있는 가장 실용적인 첫 단계입니다.

## 10. 배포와 권한 이슈

현재 검증은 Samsung Health 개발자 모드 기준입니다.

프로덕션 배포 시에는 아래를 다시 검토해야 합니다.

- Samsung Health Data SDK 파트너십 승인
- 앱 패키지명 / 서명(SHA-256) 등록
- 배포 빌드 서명 관리
- 자동 실행 정책 검토
- 백엔드의 공인 접근 주소 준비

즉, 현재 브랜치는 "실기기 선행 검증 성공" 단계이고, "배포 완료" 단계는 아닙니다.

## 11. 팀 인수인계 포인트

다른 팀원이 이어서 작업할 때 먼저 보면 좋은 순서는 다음과 같습니다.

1. 이 문서
2. `docs/SAMSUNG_HEALTH_API.md`
3. Android bridge UI 및 repository 코드
4. backend `samsung_health.py`

추천 후속 작업:

- `sleep_history` 를 `/briefings` 입력에 직접 포함
- `wake_time` 갱신 시 briefing 생성 자동 호출
- auto sync 성공/실패 상태를 UI에서 더 잘 보이게 개선
- Health Connect 기반 대체 경로 검토
