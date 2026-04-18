# Team Workflow

이 문서는 팀 작업 규칙용입니다.

실제 구현 전에 꼭 보면 좋은 문서는 아래입니다.

- 사람별 입력/출력 계약: `docs/INPUT_OUTPUT_SPEC.md`
- 전체 개요: `README.md`

## 파일 오너십

- 배민규: `backend/app/services/orchestrator.py`
- 조수빈: `backend/app/services/weather.py`
- 김재희: `backend/app/services/calendar.py`
- 문이현: `backend/app/services/slack_summary.py`
- 나정연: `backend/app/services/admin.py`
- 오승담: `backend/app/services/presentation.py`

## 공통 규칙

- 각자 담당 파일 밖 수정은 최소화합니다.
- 실제 외부 API 연결 전까지는 mock 동작이 깨지지 않도록 유지합니다.
- base class, interface, 추상화 계층은 만들지 않습니다.
- 각 파일은 함수 하나 또는 몇 개로 끝냅니다.
- 오케스트레이터 파일만 다른 파일을 호출합니다.
- 반환값은 `dict`를 유지합니다.
- 실데이터가 아직 없으면 mock 데이터를 기준으로 먼저 완성합니다.
- Admin과 Demo는 처음부터 mock 기준으로 설계하는 것이 정상입니다.

## 추천 브랜치

- `feat/orchestrator`
- `feat/weather`
- `feat/calendar`
- `feat/slack-summary`
- `feat/admin`
- `feat/presentation`

## 작업 순서

1. 각자 자기 `.py` 파일에서 mock 데이터를 실제 데이터로 교체합니다.
2. 반환값은 `dict`만 유지하면 됩니다.
3. 오케스트레이터는 키 이름만 맞으면 내부 구현이 바뀌어도 수정하지 않습니다.
4. UI 또는 발표 연결은 API 응답을 기준으로 진행합니다.

## 구현할 때 보면 좋은 기준

- 어떤 입력을 받아야 하는지 모르면 `docs/INPUT_OUTPUT_SPEC.md`를 봅니다.
- 어떤 키를 반환해야 하는지 모르면 자기 담당 파일의 mock 반환값을 그대로 보면 됩니다.
- 공통 구조를 바꾸고 싶으면 먼저 팀원들과 키 이름부터 맞춥니다.
- 구현 시작점이 애매하면 자기 담당 mock json부터 먼저 읽고 시작합니다.

## 머지 전 체크리스트

- `python -m compileall src`
- mock 모드에서 `/briefing` 응답 확인
- 담당 폴더 외 불필요 수정이 없는지 확인
- 새 환경변수가 생기면 `.env.example` 업데이트
