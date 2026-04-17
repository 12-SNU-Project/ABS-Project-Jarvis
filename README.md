# Jarvis Assistant Skeleton

6명이 병렬로 개발하고 마지막에 머지하기 쉽게 만든 AI 비서 프로젝트 뼈대입니다.

## 목표 기능

- UI: 메인 브리핑 화면, 기능 카드, 상태 확인
- Admin: 토큰 사용량 / 에이전트 흐름 / 기능별 실행 상태
- 발표: 데모 시나리오 및 발표용 카드/스크립트
- 날씨 + 옷 추천
- 일정 브리핑
- 슬랙 요약
- 오케스트레이션: 자연어 입력 하나로 여러 기능을 묶어 브리핑 생성

## 구조

```text
apps/
  web/                    # 프론트엔드 및 데모 화면
    app/                  # Next.js route
    team/                 # 사람별 폴더
      baemingyu-orchestrator/
      oseungdam-ui/
      najeongyeon-admin/
      josubin-weather/
      kimjaehee-calendar/
      moonihyeon-slack/
```

## 권장 역할 분배

- 배민규: `apps/web/team/baemingyu-orchestrator/*`
- 오승담: `apps/web/team/oseungdam-ui/*`
- 나정연: `apps/web/team/najeongyeon-admin/*`
- 조수빈: `apps/web/team/josubin-weather/*`
- 김재희: `apps/web/team/kimjaehee-calendar/*`
- 문이현: `apps/web/team/moonihyeon-slack/*`

## 머지 충돌 줄이는 규칙

- 각자 담당 폴더 바깥 수정은 최소화합니다.
- 공통 타입 수정은 `apps/web/team/common.ts` 한 곳에서만 합니다.
- 사람별 구현은 각자 폴더 `index.ts`에서 먼저 끝냅니다.
- UI 연결은 mock 데이터 기반으로 먼저 완성한 뒤 실제 API를 붙입니다.
- 사람 폴더끼리는 함수 호출로 직접 연결합니다.

## 개발 순서 제안

1. 각 사람은 자기 폴더 `index.ts`에서 mock을 실제 API로 바꿉니다.
2. 배민규 폴더가 각 결과를 받아 최종 브리핑으로 합칩니다.
3. 오승담은 브리핑 결과를 화면으로 표현합니다.
4. 나정연은 사람별 토큰/흐름 데이터를 Admin으로 시각화합니다.

## 실전 연결 포인트

- `apps/web/team/josubin-weather/index.ts`: 날씨 API 연결
- `apps/web/team/kimjaehee-calendar/index.ts`: 캘린더 연결
- `apps/web/team/moonihyeon-slack/index.ts`: Slack + 생성형 AI 연결
- `apps/web/team/baemingyu-orchestrator/index.ts`: 결과 조합
- `apps/web/app/api/briefing/route.ts`: 외부 호출용 브리핑 API
- `apps/web/app/api/admin/summary/route.ts`: Admin 데이터 API
- `.env.example`: 팀 공용 환경변수 기준

## 팀플 문서

- 작업 규칙: `docs/TEAM_WORKFLOW.md`
- 사람별 입출력 정리: `docs/PERSON_FOLDER_HANDOFF.md`

## 참고

- 기존에 만들어 둔 세분화된 `packages/*` 구조는 참고용으로 남아 있습니다.
- 실제 팀플 진행 기준은 `apps/web/team/*` 입니다.

## 추후 연결 포인트

- Google Calendar / Gmail
- Slack API
- Weather API
- LLM provider SDK
- Scheduler or cron

## 실행 예정 명령

```bash
npm install
npm run dev:web
```

`pnpm`을 써도 되지만, 현재 스캐폴딩은 `npm workspaces` 기준으로도 바로 동작하도록 맞춰두었습니다.
