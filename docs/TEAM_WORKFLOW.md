# Team Workflow

팀원이 6명일 때 충돌을 줄이고 빠르게 합치기 위한 작업 규칙입니다.

## 폴더 오너십

- 배민규: `apps/web/team/baemingyu-orchestrator/*`
- 오승담: `apps/web/team/oseungdam-ui/*`
- 나정연: `apps/web/team/najeongyeon-admin/*`
- 조수빈: `apps/web/team/josubin-weather/*`
- 김재희: `apps/web/team/kimjaehee-calendar/*`
- 문이현: `apps/web/team/moonihyeon-slack/*`
- Next 라우트: `apps/web/app/*`는 최대한 얇게 유지합니다.

## 브랜치 규칙

- `feat/baemingyu-orchestrator`
- `feat/oseungdam-ui`
- `feat/najeongyeon-admin`
- `feat/josubin-weather`
- `feat/kimjaehee-calendar`
- `feat/moonihyeon-slack`

## 공통 수정 규칙

- 공통 타입은 `apps/web/team/common.ts`에서만 바꿉니다.
- 환경변수는 `.env.example`에 먼저 추가한 뒤 실제 로컬 `.env`에 반영합니다.
- 사람별 구현은 각자 폴더의 `index.ts` 안에서 먼저 끝내는 것을 우선합니다.
- 폴더끼리는 함수 호출로 직접 주고받습니다.
- 추상화를 늘리기보다 파일 하나에서 읽히는 코드를 우선합니다.

## 추천 작업 순서

1. 각 사람은 자기 폴더 `index.ts`에 mock 대신 실제 연결을 붙입니다.
2. 배민규 폴더가 각 사람 폴더 결과를 최종 브리핑으로 합칩니다.
3. 오승담은 브리핑 결과를 UI에 연결합니다.
4. 나정연은 `/api/admin/summary` 기준으로 Admin을 다듬습니다.
5. 마지막에 전체 연결과 문장 라우팅을 정리합니다.

## 머지 전 체크리스트

- `npm run typecheck`
- mock 모드에서 화면 진입 확인
- 담당 폴더 외 수정 최소화 확인
- 추가 env 키가 있으면 `.env.example` 반영 확인
