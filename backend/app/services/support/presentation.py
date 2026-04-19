from __future__ import annotations

from app.providers.mock_provider import load_mock


def get_presentation_demo() -> dict:
    data = load_mock("presentation")
    return {
        "owner": "오승담",
        "feature": "presentation",
        "demo_title": data["demo_title"],
        "cards": data["cards"],
        "closing_message": data["closing_message"],
        "uses_mock": True,
    }
