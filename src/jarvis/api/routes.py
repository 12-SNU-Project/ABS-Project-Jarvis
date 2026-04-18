from __future__ import annotations

from fastapi import APIRouter

from jarvis.core.config import get_settings
from jarvis.team.admin import get_admin_summary
from jarvis.team.orchestrator import create_briefing
from jarvis.team.presentation import get_presentation_demo


router = APIRouter()
settings = get_settings()


@router.get("/health")
def health_check() -> dict:
    return {"status": "ok", "use_mocks": settings.use_mocks, "model": settings.openai_model}


@router.post("/briefing")
def create_briefing_route(payload: dict) -> dict:
    user_input = payload.get("user_input", "오늘 아침 브리핑 해줘")
    location = payload.get("location", settings.default_location)
    date = payload.get("date", settings.default_date)
    user_name = payload.get("user_name", settings.default_user_name)
    return create_briefing(
        user_input=user_input,
        location=location,
        date=date,
        user_name=user_name,
    )


@router.get("/admin/summary")
def admin_summary() -> dict:
    return get_admin_summary()


@router.get("/presentation/demo")
def presentation_demo() -> dict:
    return get_presentation_demo()
