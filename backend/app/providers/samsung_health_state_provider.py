from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from app.core.config import get_settings


def _state_path() -> Path:
    settings = get_settings()
    path = Path(settings.samsung_health_state_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def _default_state() -> dict[str, Any]:
    return {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "payload": {},
    }


def load_samsung_health_state() -> dict[str, Any]:
    path = _state_path()
    if not path.exists():
        state = _default_state()
        save_samsung_health_state(state["payload"])
        return state

    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_samsung_health_state(payload: dict[str, Any]) -> dict[str, Any]:
    path = _state_path()
    state = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "payload": payload,
    }
    with path.open("w", encoding="utf-8") as file:
        json.dump(state, file, ensure_ascii=True, indent=2)
    return state


def reset_samsung_health_state() -> dict[str, Any]:
    return save_samsung_health_state({})
