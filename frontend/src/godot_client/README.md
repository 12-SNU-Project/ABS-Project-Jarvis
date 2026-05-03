# Jarvis Desktop-Style Godot Client

현재 Godot 클라이언트는 **데스크톱 셸 레이아웃 + 아바타 자율 이동** 기준입니다.

## 현재 구성

- 메인 씬: `res://scenes/core/avatar_embed_scene.tscn`
- 메인 제어 스크립트: `res://scripts/core/avatar_embed_scene.gd`
- 아바타 씬/애니메이션: `res://scenes/components/chatbot_avatar.tscn`, `res://scripts/components/chatbot_avatar.gd`

## UI 레이아웃

- 좌측: 세로 네비게이션 바 (슬라이드 인디케이터)
- 중앙: 전체 뷰포트 아바타 활보 영역 (`Arena`)
- 우측: 알림 사이드바 + 최소 정보 카드
- 하단: 트레이 바 (알림 토글, 로밍 토글, 표정 전환, 시계)

## 동작 요약

- 아바타는 `Arena` 내부 목표점을 랜덤으로 선택해 부드럽게 이동
- 네비 탭 선택 시 상태 텍스트/표정 동기화
- 우측 알림 패널은 확장/축소 가능
- 백그라운드 모니터링: Calendar/Slack 변경 감지 후 알림 카드 + 상태 인디케이터 갱신
- 아바타 상단 버블챗 + TTS(플랫폼 지원 시)로 알림/대화 문장을 음성 재생
- `play_mood(mood: String)` 외부 호출 API 유지
- `speak_text(text: String, mood: String = "speaking")` 외부 호출 API 제공

## 백그라운드 알림 연동

`avatar_embed_scene.gd` export 변수:
- `backend_base_url` (기본: `http://127.0.0.1:8000`)
- `calendar_id` (기본: `primary`)
- `slack_channel_id` (비어 있으면 Slack 폴링 비활성)
- `monitor_interval_sec` (기본: `45`)
- `slack_lookback_hours` (기본: `24`)
- `tts_enabled` (기본: `true`)
- `tts_voice_id` (기본: 자동 선택)
- `bubble_visible_sec` (기본: `4.0`)

사용 API:
- `GET /api/v1/calendars/{calendar_id}/events?date=YYYY-MM-DD`
- `GET /api/v1/slack/activity?channel_id=...&lookback_hours=...&date=YYYY-MM-DD`

지원 mood 값:
- `idle`, `thinking`, `speaking`, `happy`, `surprised`, `sad`, `error`, `angry`, `embarrassed`
