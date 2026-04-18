# Jarvis Multi-Agent Python Skeleton

6명이 병렬로 개발하기 쉬운 Python 기반 멀티 에이전트 프로젝트 뼈대입니다.

이 프로젝트의 원칙은 하나입니다.

- 각 사람은 자기 파일 하나만 보고 개발할 수 있어야 합니다.

## 빠른 시작

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn jarvis.main:app --reload
```

확인할 API는 아래 4개입니다.

- `GET /health`
- `POST /briefing`
- `GET /admin/summary`
- `GET /presentation/demo`

## 파일 구조

```text
src/jarvis/
  api/
    routes.py
  core/
    config.py
    mock_loader.py
  team/
    orchestrator.py
    weather.py
    calendar.py
    slack_summary.py
    admin.py
    presentation.py
  data/mocks/
    weather.json
    calendar.json
    slack.json
    admin.json
    presentation.json
```

## 사람별 담당 파일

- 배민규: `src/jarvis/team/orchestrator.py`
- 조수빈: `src/jarvis/team/weather.py`
- 김재희: `src/jarvis/team/calendar.py`
- 문이현: `src/jarvis/team/slack_summary.py`
- 나정연: `src/jarvis/team/admin.py`
- 오승담: `src/jarvis/team/presentation.py`

## 사람별 입력과 출력

중요한 원칙이 하나 더 있습니다.

- 시간이 부족하면 모든 사람은 먼저 자기 mock 데이터를 기준으로 기능을 완성합니다.
- 실제 API나 실데이터 연결은 그 다음 단계입니다.
- 특히 Admin과 Demo는 처음부터 mock 기준으로 만드는 것이 맞습니다.

### 배민규 - 오케스트레이터

- 파일: `src/jarvis/team/orchestrator.py`
- 입력:
  - `user_input: str`
  - `location: str`
  - `date: str`
  - `user_name: str`
- 출력:
  - 최종 브리핑 `dict`
- 해야 하는 일:
  - 다른 사람 함수들을 호출해서 결과를 합치기
  - `headline`, `final_summary` 같은 최종 문장 만들기
  - 필요하면 나중에 스케줄링, 실패 처리, 조건 분기 추가

### 조수빈 - 날씨 + 옷 추천

- 파일: `src/jarvis/team/weather.py`
- 1차 기준 목업: `src/jarvis/data/mocks/weather.json`
- 입력:
  - `location: str`
  - `date: str`
- 출력:
  - 아래 키를 가진 `dict`
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
- 해야 하는 일:
  - mock 대신 실제 날씨 API 연결
  - 날씨 결과를 기반으로 옷 추천 문장 만들기
  - 시간이 없으면 mock 데이터 형식만 더 현실적으로 다듬어도 충분함

### 김재희 - 일정 브리핑

- 파일: `src/jarvis/team/calendar.py`
- 1차 기준 목업: `src/jarvis/data/mocks/calendar.json`
- 입력:
  - `date: str`
- 출력:
  - 아래 키를 가진 `dict`
  - `owner`
  - `feature`
  - `date`
  - `summary`
  - `events`
  - `conflicts`
  - `uses_mock`
- 해야 하는 일:
  - mock 대신 실제 일정 데이터 연결
  - 일정 요약 문장 만들기
  - 겹치는 일정이나 이동 위험 같은 conflict 만들기
  - 시간이 없으면 mock 일정 데이터만 더 현실적으로 다듬어도 충분함

### 문이현 - 슬랙 요약

- 파일: `src/jarvis/team/slack_summary.py`
- 1차 기준 목업: `src/jarvis/data/mocks/slack.json`
- 입력:
  - `user_input: str`
  - `date: str`
- 출력:
  - 아래 키를 가진 `dict`
  - `owner`
  - `feature`
  - `date`
  - `summary`
  - `channels`
  - `uses_mock`
- 해야 하는 일:
  - mock 대신 Slack 메시지 수집으로 교체
  - 필요한 채널 요약 만들기
  - action item이 필요하면 `channels` 안에 넣기
  - 시간이 없으면 mock 메시지와 요약 품질만 높여도 충분함

### 나정연 - Admin

- 파일: `src/jarvis/team/admin.py`
- 1차 기준 목업: `src/jarvis/data/mocks/admin.json`
- 입력:
  - 현재 없음
- 출력:
  - 아래 키를 가진 `dict`
  - `owner`
  - `feature`
  - `summary`
  - `top_token_feature`
  - `metrics`
  - `flow_nodes`
  - `flow_edges`
  - `uses_mock`
- 해야 하는 일:
  - 먼저 mock 데이터를 기준으로 Admin 응답과 화면 구성을 완성
  - 이후 가능하면 실제 로그/토큰 데이터로 교체
  - 어떤 기능이 무거운지 보여주는 데이터 만들기
  - 에이전트 흐름 시각화용 노드/엣지 데이터 만들기
  - 즉, 처음에는 운영 데이터가 없어도 괜찮고 mock 기준으로 만드는 게 맞음

### 오승담 - 발표 / 데모

- 파일: `src/jarvis/team/presentation.py`
- 1차 기준 목업: `src/jarvis/data/mocks/presentation.json`
- 입력:
  - 현재 없음
- 출력:
  - 아래 키를 가진 `dict`
  - `owner`
  - `feature`
  - `demo_title`
  - `cards`
  - `closing_message`
  - `uses_mock`
- 해야 하는 일:
  - 먼저 mock 데이터를 기준으로 발표 흐름과 카드 구성을 완성
  - 이후 가능하면 실제 발표 흐름 또는 UI 연결 데이터로 교체
  - 발표에서 보여줄 카드와 설명 문구 만들기
  - 즉, 처음에는 실사용 데이터가 아니라 발표용 시나리오 목업을 만드는 게 맞음

## API 입력 예시

`POST /briefing`

```json
{
  "user_input": "오늘 외근 가기 전에 전체 브리핑 해줘",
  "location": "Seoul",
  "date": "2026-04-18",
  "user_name": "Team Jarvis"
}
```

## 팀 작업 규칙

- 각 사람은 자기 파일 하나만 우선 수정합니다.
- 복잡한 추상화, base class, interface는 넣지 않습니다.
- 반환값은 `dict`로 유지합니다.
- 다른 사람 코드와 직접 연결하지 않습니다.
- 최종 조합은 `orchestrator.py`에서만 합니다.
- 실데이터가 없으면 mock 데이터를 기준으로 먼저 완성합니다.

## 참고 문서

- 상세 작업 규칙: `docs/TEAM_WORKFLOW.md`
- 사람별 입력/출력 계약: `docs/INPUT_OUTPUT_SPEC.md`
