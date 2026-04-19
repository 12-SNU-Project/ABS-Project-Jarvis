# Samsung Health API Contract

이 문서는 현재 브랜치에서 추가된 Samsung Health 관련 백엔드 API 계약을 정리합니다.

## 1. 목적

Samsung Health 는 Android 브리지 앱을 통해 raw payload 를 업로드하고, 백엔드는 그 데이터를 정규화해 웹 / 프론트 / 오케스트레이터가 소비하기 쉬운 형태로 제공합니다.

현재 목적은 다음과 같습니다.

- 프론트에서 "최근 수면 / 기상 상태"를 조회할 수 있게 하기
- 향후 "기상 직후 briefing 자동 실행"을 위한 입력 계층 확보

## 2. Base Path

현재 health 관련 경로는 `api/v1` 아래에 있습니다.

```text
/api/v1/health/sleep
/api/v1/health/sleep/bridge
```

## 3. GET /api/v1/health/sleep

### 역할

현재 저장된 Samsung Health sleep payload 를 summary 형태로 정규화해 반환합니다.

### 사용 주체

- 웹 프론트
- 브리핑 트리거 로직
- 디버깅 / 운영 확인용 도구

### 응답 성격

- mock 모드면 mock data
- 실연동 모드면 최신 브리지 업로드 payload 기반 summary
- 외부 연결이 비어 있으면 fallback summary

### 예시 응답

```json
{
  "source": "samsung_health",
  "uses_mock": false,
  "integration_mode": "android_sdk_bridge",
  "partnership_required": true,
  "developer_mode_supported": true,
  "health_data_type": "sleep",
  "range_days": 7,
  "recent_nights_count": 5,
  "detected_at": "2026-04-19T11:08:31.132714+00:00",
  "wake_time": "2026-04-19T09:00:00+09:00",
  "sleep_start": "2026-04-19T02:10:00+09:00",
  "sleep_end": "2026-04-19T09:00:00+09:00",
  "sleep_duration_minutes": 410,
  "average_sleep_duration_minutes": 398,
  "average_wake_time": "2026-04-19T07:16:00+09:00",
  "sleep_debt_minutes_vs_target": 410,
  "sleep_history": [
    {
      "sleep_start": "2026-04-19T02:10:00+09:00",
      "sleep_end": "2026-04-19T09:00:00+09:00",
      "wake_time": "2026-04-19T09:00:00+09:00",
      "sleep_duration_minutes": 410,
      "status": "awake"
    }
  ],
  "assistant_actions": [
    "최근 수면 이력을 기반으로 오늘 브리핑 시작 시간을 기상 직후로 조정합니다."
  ],
  "today_sleep_recommendation": "최근 수면 부족이 누적되어 오늘은 늦은 일정과 카페인 섭취를 줄이고 일찍 쉬는 것이 좋습니다.",
  "status": "awake",
  "summary": "Imported from Samsung Health bridge",
  "integration_notes": "Samsung Health Data SDK는 Android 앱에서 HealthDataStore 연결과 PermissionManager 권한 요청 후 Sleep 데이터를 읽어와야 하며, 프로덕션 배포에는 파트너십 승인이 필요합니다. 개발 단계에서는 Samsung Health 개발자 모드와 Android 브리지 앱으로 선행 검증이 가능합니다."
}
```

## 4. POST /api/v1/health/sleep/bridge

### 역할

Android 브리지 앱이 Samsung Health sleep raw payload 를 서버에 업로드하는 엔드포인트입니다.

### 인증

헤더:

```text
X-Bridge-Token: <SAMSUNG_HEALTH_BRIDGE_TOKEN>
```

서버 환경변수 `SAMSUNG_HEALTH_BRIDGE_TOKEN` 과 일치해야 합니다.

### 요청 예시

```json
{
  "health_data_type": "sleep",
  "detected_at": null,
  "range_days": 7,
  "status": "awake",
  "items": [
    {
      "start_time": 1776532200000,
      "end_time": 1776556800000,
      "time_offset": 32400000,
      "comment": "Imported from Samsung Health bridge"
    }
  ]
}
```

### 처리 흐름

1. 토큰 검증
2. raw payload 를 state file 에 저장
3. 저장된 payload 를 summary 형태로 정규화
4. `GET /api/v1/health/sleep` 와 같은 schema 로 응답

## 5. Raw Payload Schema

Android 브리지는 현재 아래 shape 을 사용합니다.

### 루트 필드

- `health_data_type`: 현재 `"sleep"`
- `detected_at`: 조회 시각 또는 `null`
- `range_days`: 최근 며칠을 읽었는지
- `status`: 현재 `"awake"`
- `items`: sleep item 배열

### item 필드

- `start_time`
  - epoch ms
- `end_time`
  - epoch ms
- `time_offset`
  - timezone offset ms
- `comment`
  - 브리지 메모

## 6. Summary 계산 규칙

백엔드는 raw payload 로부터 아래 규칙으로 summary 를 만듭니다.

### 최신 수면 선택

- `items` 중 `sleep_end` 기준 최신 항목을 현재 수면 record 로 간주

### 기상 시각

- 현재 구현에서는 `wake_time = sleep_end`

### 수면 시간

- `sleep_duration_minutes = (end_time - start_time) / 60000`

### 평균 수면 시간

- `sleep_history` 전체의 평균

### 평균 기상 시각

- 각 `wake_time` 을 분 단위로 환산해 평균 계산

### 수면 부족

- 최근 nights 수 × 8시간을 목표로 보고 부족분을 분 단위 계산

## 7. 상태 저장

서버는 최신 raw payload 를 파일에 저장합니다.

환경변수:

```env
SAMSUNG_HEALTH_STATE_PATH=/tmp/jarvis-samsung-health-state.json
```

파일 구조 예시:

```json
{
  "updated_at": "2026-04-19T11:08:00.780175+00:00",
  "payload": {
    "health_data_type": "sleep",
    "range_days": 7,
    "status": "awake",
    "items": []
  }
}
```

## 8. Mock / Real 동작 구분

### Mock

```env
SAMSUNG_HEALTH_USE_MOCK=true
```

- `/api/v1/health/sleep` 는 `backend/app/data/mocks/samsung_health.json` 기반 응답

### Real bridge

```env
SAMSUNG_HEALTH_USE_MOCK=false
```

- 최신 브리지 업로드 payload 기반 응답

## 9. 프론트 사용 포인트

프론트는 현재 `frontend/src/features/briefing/api/briefingApi.ts` 에서 이 API 를 붙일 수 있습니다.

권장 사용 방식:

- 페이지 진입 시 `GET /api/v1/health/sleep`
- `wake_time`, `sleep_duration_minutes`, `sleep_history` 표시
- `recent_nights_count > 0` 이고 `wake_time` 이 오늘이면 기상 기반 브리핑 트리거 후보로 사용

## 10. 현재 제약

- 현재 데이터 타입은 `sleep` 중심
- `sleep_stage`, `blood_oxygen`, `skin_temperature` 는 아직 summary 에 포함되지 않음
- auto sync 는 앱 백그라운드 정책상 약 15분 주기
- 기상 직후 "즉시" 트리거는 아직 아님

## 11. 후속 확장 권장

추천 후속 작업:

- `/briefings` 입력에 `health` 섹션 추가
- `wake_time` 기반 브리핑 자동 생성 API 연결
- `sleep_stage` / `sleep_score` 반영
- 프론트에 "최근 수면 추세" 카드 추가
- auto sync 성공 / 실패 상태 확인용 endpoint 추가
