# Slack Summary API Spec

## 목적

- Slack 채널의 최근 대화 내용을 읽는다.
- 최근 `lookback_hours` 시간 범위의 전체 메시지를 수집한다.
- 수집한 메시지를 LLM으로 5줄 요약한다.
- 프론트엔드가 바로 사용할 수 있도록 JSON으로 반환한다.

---

## 구현 포인트

### 1. Health Check

- `GET /api/v1/health`
- 서버 상태 확인용

응답 예시

```json
{
  "status": "ok",
  "use_mocks": false,
  "model": "gpt-5.4-mini"
}
```

### 2. Slack Summary API

- `POST /api/v1/slack/summary`
- 특정 Slack 채널의 최근 대화를 읽고 5줄 요약 반환

처리 흐름

1. 요청으로 `channel_id`, `lookback_hours` 등을 받음
2. Slack API로 최근 `lookback_hours` 시간 동안의 메시지 조회
3. 시스템 메시지(`channel_join`, `channel_leave`) 제외
4. OpenAI API로 5줄 요약 생성
5. 원본 메시지와 요약 결과를 JSON으로 반환

---

## Request Spec

### Endpoint

```http
POST /api/v1/slack/summary
Content-Type: application/json
```

### Request Body

```json
{
  "channel_id": "C0A46076AEM",
  "user_input": "최근 1일 대화 핵심을 5줄로 요약해줘",
  "date": "2026-04-18",
  "lookback_hours": 24
}
```

### Request Fields

| 필드 | 타입 | 필수 여부 | 설명 |
| --- | --- | --- | --- |
| `channel_id` | `string` | 필수 | Slack 채널 ID |
| `user_input` | `string` | 선택 | 요약 요청 문장 |
| `date` | `string` | 선택 | 기준 날짜 |
| `lookback_hours` | `integer` | 선택 | 최근 몇 시간치 메시지를 읽을지, 기본값 `24`, 범위 `1~168` |

---

## Response Spec

### Success Response

```json
{
  "owner": "문이현",
  "feature": "slack_summary",
  "uses_mock": false,
  "date": "2026-04-18",
  "channel_id": "C0A46076AEM",
  "channel_name": "#새-워크스페이스-전체",
  "lookback_hours": 24,
  "message_count": 47,
  "summary": "핀테크·암호 과제와 암호문 제출 과제의 마감이 헷갈려서, 과제별 제출일을 다시 확인해야 한다는 얘기가 나왔다.\n과제 1,2는 내일까지 제출이고, 일부 과제는 24일까지, 암호문 과제는 주말 마감으로 기억하는 등 일정 정리가 필요하다.\n기업 배정 결과는 빠르면 금요일, 늦어도 주말까지 안내 예정이었지만 아직 연락이 없어 모두 궁금해하고 있다.\n응용특강 과제는 난이도가 높고 협업도 복잡해서 힘들다는 반응이 있었고, 발표는 다음주 화요일 21일로 확인했다.\n서로 오늘 한 일과 반려동물 이야기를 나누며 분위기를 풀었고, 남은 과제와 발표를 위해 다 같이 화이팅하자는 분위기였다.",
  "summary_lines": [
    "핀테크·암호 과제와 암호문 제출 과제의 마감이 헷갈려서, 과제별 제출일을 다시 확인해야 한다는 얘기가 나왔다.",
    "과제 1,2는 내일까지 제출이고, 일부 과제는 24일까지, 암호문 과제는 주말 마감으로 기억하는 등 일정 정리가 필요하다.",
    "기업 배정 결과는 빠르면 금요일, 늦어도 주말까지 안내 예정이었지만 아직 연락이 없어 모두 궁금해하고 있다.",
    "응용특강 과제는 난이도가 높고 협업도 복잡해서 힘들다는 반응이 있었고, 발표는 다음주 화요일 21일로 확인했다.",
    "서로 오늘 한 일과 반려동물 이야기를 나누며 분위기를 풀었고, 남은 과제와 발표를 위해 다 같이 화이팅하자는 분위기였다."
  ],
  "messages": [
    {
      "user": "U0A3T2ANT50",
      "text": "주말까지 해야하는 과제가 뭐가 있지?",
      "ts": "1776512027.597539"
    }
  ],
  "model": "gpt-5.4-mini"
}
```

### Response Fields

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `owner` | `string` | 담당자 이름 |
| `feature` | `string` | 기능 이름 |
| `uses_mock` | `boolean` | mock 응답 여부 |
| `date` | `string` | 기준 날짜 |
| `channel_id` | `string` | Slack 채널 ID |
| `channel_name` | `string` | Slack 채널 이름 |
| `lookback_hours` | `integer` | 조회 시간 범위 |
| `message_count` | `integer` | 실제 요약에 사용한 메시지 수 |
| `summary` | `string` | 줄바꿈 포함 5줄 요약 |
| `summary_lines` | `string[]` | 5줄 요약 배열 |
| `messages` | `object[]` | 원본 메시지 목록 |
| `model` | `string` | 사용한 LLM 모델명 |

### Message Object

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `user` | `string` | Slack user ID |
| `text` | `string` | 메시지 본문 |
| `ts` | `string` | Slack timestamp |

---

## Error Response

### 400 Bad Request

- 잘못된 파라미터 값

예시

```json
{
  "detail": "lookback_hours must be between 1 and 168."
}
```

### 422 Unprocessable Entity

- 요청 JSON 형식이 잘못된 경우

### 502 Bad Gateway

- Slack 또는 OpenAI 호출 실패

예시

```json
{
  "detail": "Slack bot is not in the channel. Invite the app to that channel with /invite @your-app-name and try again."
}
```

---

## 환경변수

```env
JARVIS_USE_MOCKS=false
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-5.4-mini
SLACK_BOT_TOKEN=...
SLACK_CHANNEL_ID=C0A46076AEM
SLACK_LOOKBACK_HOURS=24
```

---

## 로컬 테스트 예시

```bash
curl -X POST http://127.0.0.1:8000/api/v1/slack/summary \
  -H 'Content-Type: application/json' \
  -d '{
    "channel_id": "C0A46076AEM",
    "user_input": "최근 1일 대화 핵심을 5줄로 요약해줘",
    "date": "2026-04-18",
    "lookback_hours": 24
  }'
```

요약만 보고 싶을 때

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/slack/summary \
  -H 'Content-Type: application/json' \
  -d '{
    "channel_id": "C0A46076AEM",
    "user_input": "최근 1일 대화 핵심을 5줄로 요약해줘",
    "date": "2026-04-18",
    "lookback_hours": 24
  }' | python -c "import sys,json; [print(x) for x in json.load(sys.stdin)['summary_lines']]"
```

---

## 프론트엔드 전달 포인트

- 프론트는 `POST /slack/summary`만 호출하면 됨
- 요청 시 `channel_id`와 `lookback_hours`를 넘기면 됨
- 화면에서는 `summary_lines`를 그대로 리스트 형태로 렌더링하면 됨
- 필요하면 `messages`를 디버그/상세보기 용도로 활용 가능
