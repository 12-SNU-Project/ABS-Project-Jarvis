# Person Folder Handoff

현재 실개발 기준 구조는 `apps/web/team/*` 입니다.

## 사람 폴더 구조

- `apps/web/team/baemingyu-orchestrator`
- `apps/web/team/oseungdam-ui`
- `apps/web/team/najeongyeon-admin`
- `apps/web/team/josubin-weather`
- `apps/web/team/kimjaehee-calendar`
- `apps/web/team/moonihyeon-slack`

## 공통 규칙

- 각 사람은 자기 폴더의 `index.ts`만 우선 수정합니다.
- 사람 폴더끼리는 함수 호출로 직접 주고받습니다.
- 복잡한 interface/client 계층은 만들지 않습니다.
- 공통 입력은 `apps/web/team/common.ts`의 `BriefingInput` 하나만 씁니다.

## 입력과 출력

### 배민규 폴더

- 입력: `userInput`, `location`, `date`
- 출력: 최종 브리핑
- 해야 할 일: 다른 사람 폴더 호출, 결과 합치기, fallback 처리

### 조수빈 폴더

- 입력: `location`, `date`
- 출력: 날씨 + 옷 추천 섹션
- 해야 할 일: 날씨 API 연결, 옷 추천 문장 규칙

### 김재희 폴더

- 입력: `date`
- 출력: 일정 브리핑 섹션
- 해야 할 일: Google Calendar 연결, 중요 일정/충돌 요약

### 문이현 폴더

- 입력: `userInput`, `date`
- 출력: 슬랙 요약 섹션
- 해야 할 일: Slack 메시지 수집, 생성형 AI 요약, 액션 아이템 추출

### 오승담 폴더

- 입력: 브리핑 결과, 폴더 정보, 발표 흐름
- 출력: 홈/브리핑 화면에 넣을 UI용 데이터
- 해야 할 일: 메인 화면과 발표 흐름 표현

### 나정연 폴더

- 입력: 토큰 사용량, 최근 실행 로그, 폴더 흐름
- 출력: Admin 대시보드 데이터
- 해야 할 일: 시각화 구조, 사람별 오너십 정리

## 생성형 AI에게 줄 작업 요청 예시

- 배민규: "각 사람 폴더의 결과를 받아 최종 브리핑으로 합치는 간단한 함수만 작성해줘. 불필요한 추상화는 만들지 마."
- 조수빈: "이 파일 하나에서 날씨 API를 호출하고 결과를 브리핑 문장으로 바꿔줘. 반환 형식은 현재 객체 구조를 유지해줘."
- 김재희: "Google Calendar에서 오늘 일정을 읽고 중요한 일정 수와 요약 문장을 만들어줘."
- 문이현: "Slack 메시지를 읽고 summary와 actionItems 중심으로 짧게 요약해줘."
- 오승담: "받은 브리핑 결과를 보기 좋은 카드형 UI 데이터로 정리해줘."
- 나정연: "사람별 토큰 사용량과 실행 흐름을 Admin 화면에 넣기 쉬운 JSON으로 정리해줘."
