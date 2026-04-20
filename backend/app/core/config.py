from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from tempfile import gettempdir


def _as_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _load_dotenv() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    backend_root = Path(__file__).resolve().parents[2]

    for env_path in (repo_root / ".env", backend_root / ".env"):
        if not env_path.exists():
            continue

        for raw_line in env_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue

            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()

            if (
                len(value) >= 2
                and value[0] == value[-1]
                and value[0] in {'"', "'"}
            ):
                value = value[1:-1]

            os.environ.setdefault(key, value)


_load_dotenv()


@dataclass(frozen=True)
class Settings:
    use_mocks: bool = True
    default_location: str = "Seoul"
    default_user_name: str = "Team Jarvis"
    default_date: str = str(date.today())
    default_timezone: str = "Asia/Seoul"
    calendar_provider: str = "mock"
    calendar_state_path: str = os.path.join(gettempdir(), "jarvis-calendar-state.json")
    openai_api_key: str = ""
    openai_model: str = "gpt-5.4-mini"
    openai_timeout_seconds: float = 45.0
    openai_transcription_model: str = "gpt-4o-transcribe"
    openai_tts_model: str = "gpt-4o-mini-tts"
    openai_tts_voice: str = "cedar"
    slack_bot_token: str = ""
    slack_channel_id: str = ""
    slack_lookback_hours: int = 24
    samsung_health_use_mock: bool = True
    samsung_health_api_url: str = ""
    samsung_health_api_key: str = ""
    samsung_health_bridge_token: str = ""
    samsung_health_state_path: str = os.path.join(gettempdir(), "jarvis-samsung-health-state.json")


def get_settings() -> Settings:
    return Settings(
        use_mocks=_as_bool(os.getenv("JARVIS_USE_MOCKS"), True),
        default_location=os.getenv("JARVIS_DEFAULT_LOCATION", "Seoul"),
        default_user_name=os.getenv("JARVIS_DEFAULT_USER_NAME", "Team Jarvis"),
        default_date=os.getenv("JARVIS_DEFAULT_DATE", str(date.today())),
        default_timezone=os.getenv("JARVIS_DEFAULT_TIMEZONE", "Asia/Seoul"),
        calendar_provider=os.getenv("JARVIS_CALENDAR_PROVIDER", "mock"),
        calendar_state_path=os.getenv(
            "JARVIS_CALENDAR_STATE_PATH",
            os.path.join(gettempdir(), "jarvis-calendar-state.json"),
        ),
        openai_api_key=os.getenv("OPENAI_API_KEY", ""),
        openai_model=os.getenv("OPENAI_MODEL", "gpt-5.4-mini"),
        openai_timeout_seconds=float(os.getenv("OPENAI_TIMEOUT_SECONDS", "45")),
        openai_transcription_model=os.getenv(
            "OPENAI_TRANSCRIPTION_MODEL", "gpt-4o-transcribe"
        ),
        openai_tts_model=os.getenv("OPENAI_TTS_MODEL", "gpt-4o-mini-tts"),
        openai_tts_voice=os.getenv("OPENAI_TTS_VOICE", "cedar"),
        slack_bot_token=os.getenv("SLACK_BOT_TOKEN", ""),
        slack_channel_id=os.getenv("SLACK_CHANNEL_ID", ""),
        slack_lookback_hours=int(os.getenv("SLACK_LOOKBACK_HOURS", "24")),
        samsung_health_use_mock=_as_bool(os.getenv("SAMSUNG_HEALTH_USE_MOCK"), True),
        samsung_health_api_url=os.getenv("SAMSUNG_HEALTH_API_URL", ""),
        samsung_health_api_key=os.getenv("SAMSUNG_HEALTH_API_KEY", ""),
        samsung_health_bridge_token=os.getenv("SAMSUNG_HEALTH_BRIDGE_TOKEN", ""),
        samsung_health_state_path=os.getenv(
            "SAMSUNG_HEALTH_STATE_PATH",
            os.path.join(gettempdir(), "jarvis-samsung-health-state.json"),
        ),
    )
