from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[3]
BACKEND_ROOT = Path(__file__).resolve().parents[2]

load_dotenv(REPO_ROOT / ".env")
load_dotenv(BACKEND_ROOT / ".env")


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
    openai_api_key: str = ""
    openai_model: str = "gpt-5.4-mini"
    slack_bot_token: str = ""
    slack_channel_id: str = ""
    slack_lookback_hours: int = 24


def get_settings() -> Settings:
    return Settings(
        use_mocks=_as_bool(os.getenv("JARVIS_USE_MOCKS"), True),
        default_location=os.getenv("JARVIS_DEFAULT_LOCATION", "Seoul"),
        default_user_name=os.getenv("JARVIS_DEFAULT_USER_NAME", "Team Jarvis"),
        default_date=os.getenv("JARVIS_DEFAULT_DATE", str(date.today())),
        openai_api_key=os.getenv("OPENAI_API_KEY", ""),
        openai_model=os.getenv("OPENAI_MODEL", "gpt-5.4-mini"),
        slack_bot_token=os.getenv("SLACK_BOT_TOKEN", ""),
        slack_channel_id=os.getenv("SLACK_CHANNEL_ID", ""),
        slack_lookback_hours=int(os.getenv("SLACK_LOOKBACK_HOURS", "24")),
    )
