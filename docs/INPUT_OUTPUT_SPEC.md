# Input Output Spec

이 문서는 각 사람이 자기 기능을 구현할 때 필요한 입력과 출력만 빠르게 확인하기 위한 문서입니다.

원칙은 간단합니다.

- 각 사람은 자기 파일 하나만 수정합니다.
- 입력 함수 시그니처는 가급적 유지합니다.
- 출력은 `dict` 키 이름만 맞추면 됩니다.
- 실데이터가 아직 없으면 먼저 mock json을 기준으로 완성하면 됩니다.
- 특히 Admin과 Demo는 초기 단계에서 mock 기준으로 만드는 것이 맞습니다.

## 1. 오케스트레이터

- 담당자: 배민규
- 파일: `backend/app/services/orchestrator.py`
- 함수: `create_briefing(user_input: str, location: str, date: str, user_name: str) -> FinalBriefing`
- 참고 목업:
  - weather: `backend/app/data/mocks/weather.json`
  - calendar: `backend/app/data/mocks/calendar.json`
  - slack: `backend/app/data/mocks/slack.json`
  - admin: `backend/app/data/mocks/admin.json`
  - presentation: `backend/app/data/mocks/presentation.json`

입력

- `user_input`
  - 사용자가 입력한 자연어 요청
  - 예시: `"오늘 외근 가기 전에 전체 브리핑 해줘"`
- `location`
  - 사용자 기준 위치
  - 예시: `"Seoul"`
- `date`
  - 브리핑 기준 날짜 문자열
  - 예시: `"2026-04-18"`
- `user_name`
  - 사용자 이름
  - 예시: `"Team Jarvis"`

출력

- 최종 브리핑 `dict`
- 필수 키
  - `headline`
  - `generated_for`
  - `user_input`
  - `weather`
  - `calendar`
  - `slack`
  - `admin`
  - `presentation`
  - `final_summary`

해야 하는 일

- 각 사람의 함수 호출
- 결과를 한 JSON으로 합치기
- 최종 요약 문장 만들기
- 실데이터가 덜 붙어도 mock 출력이 오면 전체 브리핑이 깨지지 않게 유지하기

## 2. 날씨 + 옷 추천

- 담당자: 조수빈
- 파일: `backend/app/services/weather.py`
- 함수: `get_weather_brief(location: str, date: str) -> WeatherBrief`
- 참고 목업: `backend/app/data/mocks/weather.json`

입력

- `location`
  - 위치 문자열
  - 예시: `"Seoul"`
- `date`
  - 날짜 문자열
  - 예시: `"2026-04-18"`

출력

- 필수 키
  - `owner`
  - `feature`
  - `location`
  - `date`
  - `summary`
  - `temperature_c`
  - `condition`
  - `recommendation`
  - `items`
  - `uses_mock`

예상 출력 예시

```json
{
  "owner": "조수빈",
  "feature": "weather",
  "location": "Seoul",
  "date": "2026-04-18",
  "summary": "Seoul 기준 맑고 일교차가 있어 가벼운 겉옷이 필요합니다.",
  "temperature_c": 17,
  "condition": "sunny",
  "recommendation": "얇은 니트나 셔츠 위에 가벼운 자켓을 추천합니다.",
  "items": ["light jacket", "shirt", "sneakers"],
  "uses_mock": true
}
```

1차 목표

- mock 기준으로 함수 완성
- 나중에 가능하면 실제 날씨 API로 교체

## 3. 일정 브리핑

- 담당자: 김재희
- 파일: `backend/app/services/calendar.py`
- 대표 함수: `get_calendar_brief(date: str, calendar_id: str = "primary") -> CalendarBrief`
- 참고 목업: `backend/app/data/mocks/calendar.json`

현재 구조

- `backend/app/services/calendar.py`
  - 캘린더 도메인 facade
  - 다른 레이어는 이 파일만 import해도 되도록 유지
- 실제 읽기/쓰기 로직은 아래로 분리됨
  - `backend/app/services/calendar_read.py`
  - `backend/app/services/calendar_conflicts.py`
  - `backend/app/services/calendar_write.py`
  - `backend/app/services/calendar_audit.py`

현재 캘린더는 단순 브리핑용 mock 함수만 있는 상태가 아니라,

- 브리핑용 일정 요약
- 일정 조회
- 충돌 탐지
- 제안 기반 일정 수정(create/update/move/delete)
- 제안 실행/거절
- audit log

까지 포함하는 구조로 확장되어 있습니다.

입력

- `date`
  - 날짜 문자열
  - 예시: `"2026-04-18"`
- `calendar_id`
  - 선택값
  - 기본값: `"primary"`
  - 예시: `"primary"`

출력

- 필수 키
  - `owner`
  - `feature`
  - `calendar_id`
  - `date`
  - `summary`
  - `events`
  - `conflicts`
  - `uses_mock`

`events` 내부 현재 키

- `id`
- `calendar_id`
- `title`
- `start`
- `end`
- `description`
- `location`
- `priority`
- `all_day`
- `recurring`
- `recurrence_rule`
- `recurrence_interval_days`
- `recurrence_count`
- `series_id`

`conflicts` 내부 현재 키

- `type`
- `message`
- `severity`
- `event_ids`

현재 `get_calendar_brief()` 출력 예시

```json
{
  "owner": "",
  "feature": "calendar",
  "uses_mock": true,
  "calendar_id": "primary",
  "date": "2026-04-18",
  "summary": "5 scheduled event(s) for 2026-04-18, including 2 high-priority item(s). No timing conflicts detected.",
  "events": [
    {
      "id": "evt-1",
      "calendar_id": "primary",
      "title": "데일리 스탠드업",
      "start": "2026-04-18T09:30:00+09:00",
      "end": "2026-04-18T10:00:00+09:00",
      "description": null,
      "location": "Zoom",
      "priority": "high",
      "all_day": false,
      "recurring": false,
      "recurrence_rule": null,
      "recurrence_interval_days": null,
      "recurrence_count": null,
      "series_id": null
    }
  ],
  "conflicts": []
}
```

추가 조회 함수

- `list_calendars_response()`
  - 현재 사용 가능한 calendar 목록 반환
- `get_calendar_detail_response(calendar_id: str)`
  - 단일 calendar metadata 반환
- `get_calendar_events_response(calendar_id: str, *, date_value: str | None = None, start_date: str | None = None, end_date: str | None = None)`
  - 단일 날짜 또는 날짜 범위의 event 목록 반환
- `get_calendar_conflicts_response(calendar_id: str, *, date_value: str | None = None, start_date: str | None = None, end_date: str | None = None)`
  - 충돌 목록 반환
- `get_calendar_summary_response(calendar_id: str, *, date_value: str | None = None, start_date: str | None = None, end_date: str | None = None)`
  - summary + events + conflicts 반환

날짜 조회 규칙

- `date` 하나만 쓰거나
- `start_date` + `end_date`를 같이 써야 함
- 둘을 섞으면 `422`

현재 mutation 구조

- 직접 수정하지 않고 먼저 proposal을 만듭니다.
- proposal을 나중에 execute 하거나 reject 합니다.
- 현재 지원 operation
  - `create_event`
  - `update_event`
  - `move_event`
  - `delete_event`
  - `create_calendar`
  - `delete_calendar`

proposal request 주요 키

- `operation_type`
- `actor`
- `calendar_id`
- `event_id`
- `recurring_scope`
- `event`
- `calendar`

proposal response 주요 키

- `proposal_id`
- `operation_type`
- `status`
- `actor`
- `target_summary`
- `calendar_id`
- `event_id`
- `recurring_scope`
- `requires_confirmation`
- `warnings`
- `before_state`
- `after_state`
- `snapshot_hash`
- `created_at`
- `executed_at`
- `error_message`

execute request 주요 키

- `proposal_id`
- `snapshot_hash`
- `confirmed`

reject request 주요 키

- `proposal_id`
- `reason`

audit record 주요 키

- `audit_id`
- `proposal_id`
- `operation_type`
- `actor`
- `calendar_id`
- `event_id`
- `recurring_scope`
- `warnings`
- `before_state`
- `after_state`
- `result_status`
- `error_message`
- `recorded_at`

1차 목표

- mock 기준으로 함수 완성
- 나중에 가능하면 실제 캘린더 데이터로 교체

## 4. 슬랙 요약

- 담당자: 문이현
- 파일: `backend/app/services/slack_summary.py`
- 함수: `get_slack_brief(user_input: str, date: str) -> [FeatureModel]`
- 참고 목업: `backend/app/data/mocks/slack.json`

입력

- `user_input`
  - 사용자의 요청 문장
- `date`
  - 날짜 문자열

출력

- 필수 키
  - `owner`
  - `feature`
  - `date`
  - `summary`
  - `channels`
  - `uses_mock`

`channels` 내부 권장 키

- `channel`
- `summary`
- `action_items`

1차 목표

- mock 기준으로 함수 완성
- 나중에 가능하면 실제 Slack API와 요약 로직으로 교체

## 5. Admin

- 담당자: 나정연
- 파일: `backend/app/services/admin.py`
- 함수: `get_admin_summary() -> [FeatureModel]`
- 참고 목업: `backend/app/data/mocks/admin.json`

입력

- 현재 없음

출력

- 필수 키
  - `owner`
  - `feature`
  - `summary`
  - `top_token_feature`
  - `metrics`
  - `flow_nodes`
  - `flow_edges`
  - `uses_mock`

`metrics` 내부 권장 키

- `feature`
- `owner`
- `token_estimate`
- `latency_ms`
- `status`

`flow_nodes` 내부 권장 키

- `id`
- `label`
- `group`

`flow_edges` 내부 권장 키

- `source`
- `target`
- `label`

중요

- Admin은 처음부터 실제 운영 데이터가 없어도 됩니다.
- 먼저 `admin.json` 목업 기준으로 응답 구조나 화면 구성을 완성하면 됩니다.
- 나중에 가능하면 아래 데이터로 교체합니다.
  - 기능별 실행 로그
  - 응답 시간
  - 토큰 사용량 또는 추정치
  - 에이전트 흐름 데이터

## 6. 발표 / 데모

- 담당자: 오승담
- 파일: `backend/app/services/presentation.py`
- 함수: `get_presentation_demo() -> [FeatureModel]`
- 참고 목업: `backend/app/data/mocks/presentation.json`

입력

- 현재 없음

출력

- 필수 키
  - `owner`
  - `feature`
  - `demo_title`
  - `cards`
  - `closing_message`
  - `uses_mock`

`cards` 내부 권장 키

- `title`
- `description`
- `talking_points`

중요

- Demo는 처음부터 실사용 데이터가 없어도 됩니다.
- 먼저 `presentation.json` 목업 기준으로 발표 카드와 설명 흐름을 완성하면 됩니다.
- 나중에 가능하면 아래 데이터로 교체합니다.
  - 실제 발표 순서
  - 실제 UI 화면 설명
  - 시연 중 강조할 포인트

## 공통 주의사항

- 키 이름은 함부로 바꾸지 않는 것이 좋습니다.
- 실제 API를 붙여도 반환 형식만 유지하면 다른 사람 코드는 거의 안 건드려도 됩니다.
- 시간이 없으면 mock을 조금 더 현실적으로 바꾸는 것만 해도 충분합니다.
