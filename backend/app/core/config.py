from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import date
from tempfile import gettempdir


def _as_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    use_mocks: bool = True
    default_location: str = "Seoul"
    default_user_name: str = "Team Jarvis"
    default_date: str = str(date.today())
    default_timezone: str = "Asia/Seoul"
    calendar_provider: str = "mock"
    calendar_state_path: str = os.path.join(gettempdir(), "jarvis-calendar-state.json")
    openai_model: str = "gpt-5.4-mini"


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
        openai_model=os.getenv("OPENAI_MODEL", "gpt-5.4-mini"),
    )
