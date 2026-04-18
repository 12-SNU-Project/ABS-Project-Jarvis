from __future__ import annotations

import json
from pathlib import Path
from typing import Any


MOCK_DIR = Path(__file__).resolve().parent.parent / "data" / "mocks"


def load_mock(name: str) -> dict[str, Any]:
    path = MOCK_DIR / f"{name}.json"
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)
