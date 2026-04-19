from __future__ import annotations

import os

import uvicorn


def _flag(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def main() -> None:
    host = os.getenv("JARVIS_HOST", "127.0.0.1")
    port = int(os.getenv("JARVIS_PORT", "8000"))
    reload_enabled = _flag("JARVIS_RELOAD", True)

    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=reload_enabled,
    )

