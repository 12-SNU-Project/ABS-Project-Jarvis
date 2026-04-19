# Samsung Health Device Bridge

이 문서는 실제 삼성 스마트폰에서 Samsung Health Data SDK로 수면 데이터를 읽고, 현재 Jarvis 백엔드로 업로드하는 최소 구현 흐름을 정리합니다.

## 1. 현재 레포에서 이미 준비된 것

- 백엔드 조회 API: `GET /api/v1/health/sleep`
- Android 브리지 업로드 API: `POST /api/v1/health/sleep/bridge`
- 브리지 인증 헤더: `X-Bridge-Token`
- 업로드된 최신 삼성 헬스 raw payload 저장
- 웹용 수면 summary 정규화

관련 백엔드 환경변수:

```env
SAMSUNG_HEALTH_USE_MOCK=false
SAMSUNG_HEALTH_BRIDGE_TOKEN=replace-me
SAMSUNG_HEALTH_STATE_PATH=/tmp/jarvis-samsung-health-state.json
```

## 2. 실제 스마트폰 연결 구조

Samsung Health Data SDK는 백엔드에서 직접 호출하는 REST API가 아닙니다.

실제 연결 흐름은 다음과 같습니다.

1. 삼성 스마트폰의 Android 앱이 `HealthDataStore`에 연결
2. Android 앱이 `PermissionManager`로 `Sleep` 읽기 권한 요청
3. Android 앱이 `HealthConstants.Sleep` 데이터를 조회
4. Android 앱이 raw sleep record를 Jarvis 백엔드로 업로드
5. 웹/UI는 백엔드의 `/api/v1/health/sleep`를 조회

## 3. Android 브리지 초안 위치

이 레포에 최소 Android 스캐폴드를 추가했습니다.

- `android-bridge/`
- 핵심 Activity: `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/MainActivity.kt`
- 핵심 브리지 로직: `android-bridge/app/src/main/java/com/jarvis/samsunghealthbridge/SamsungHealthBridge.kt`

## 4. Samsung Health SDK 준비

Samsung Health Data SDK는 별도 다운로드가 필요합니다.

1. Samsung Developer에서 Data SDK를 다운로드
2. `android-bridge/app/libs/` 아래에 AAR 또는 JAR 배치
3. Android Studio에서 Gradle sync

현재 `build.gradle.kts`는 `app/libs/*.aar`와 `*.jar`를 자동으로 읽게 되어 있습니다.

## 5. 개발자 모드와 파트너십

- 개발 단계:
  - Samsung Health 개발자 모드로 테스트 가능
- 실제 배포:
  - 파트너십 승인 필요 가능성이 높음
  - 앱 정보, 패키지명, SHA-256, 데이터 플로우 설명이 필요

## 6. 가장 빠른 실기기 테스트

가장 빨리 확인하려면 아래 방식이 좋습니다.

1. 백엔드가 실행 중인 PC와 삼성폰을 같은 Wi-Fi에 연결
2. 백엔드 `.env`에 아래 값 설정

```env
SAMSUNG_HEALTH_USE_MOCK=false
SAMSUNG_HEALTH_BRIDGE_TOKEN=replace-me
```

3. 백엔드 실행 후 PC의 로컬 IP 확인
   - 예: `192.168.0.15`
4. Android 브리지 앱 실행
5. 앱 화면의 `Backend URL`에 `http://192.168.0.15:8000` 입력
6. `Bridge token`에 `.env`의 `SAMSUNG_HEALTH_BRIDGE_TOKEN` 입력
7. `Connect Samsung Health`
8. `Request Sleep Permission`
9. `Read Last 7 Days and Upload`
10. 브라우저에서 `http://192.168.0.15:8000/api/v1/health/sleep` 열어 결과 확인

## 7. 실제 테스트 순서

1. 백엔드 실행
2. `.env`에 `SAMSUNG_HEALTH_USE_MOCK=false`, `SAMSUNG_HEALTH_BRIDGE_TOKEN=...` 설정
3. Android 브리지 앱의 `BuildConfig.BACKEND_BASE_URL`, `BuildConfig.BRIDGE_TOKEN` 수정
4. 스마트폰에서 앱 실행
5. `Connect Samsung Health`
6. `Request Sleep Permission`
7. `Read Sleep and Upload`
8. 웹 또는 curl에서 `/api/v1/health/sleep` 확인

예시:

```bash
curl http://localhost:8000/api/v1/health/sleep
```

## 8. 지금 구현된 데이터 타입

1차 구현은 `HealthConstants.Sleep` 기준입니다.

추후 확장 추천:

- `HealthConstants.SleepStage`
- `HealthConstants.Exercise`
- `HealthConstants.StepDailyTrend`

아침 브리핑과의 연결성 때문에 `Sleep`과 `SleepStage`를 먼저 붙이는 것을 권장합니다.

## 9. 주의사항

- 이 Android 브리지는 초안입니다.
- 실제 기기 연결에는 Samsung Health SDK 설치와 권한 허용이 선행되어야 합니다.
- 로컬 PC에서 에뮬레이터를 쓴다면 `10.0.2.2`, 실제 스마트폰이라면 같은 네트워크에서 개발 PC IP로 백엔드 주소를 맞춰야 합니다.
- 사내/학교 네트워크 방화벽에 따라 폰에서 개발 PC의 `8000` 포트 접근이 막힐 수 있습니다.
