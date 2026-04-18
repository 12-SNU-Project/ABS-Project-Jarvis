from __future__ import annotations

from fastapi import APIRouter

from app.core.config import get_settings
from app.services.admin import get_admin_summary
from app.services.orchestrator import create_briefing
from app.services.presentation import get_presentation_demo
from app.schemas.schemas import BriefingRequest, FinalBriefing, AdminSummary, PresentationDemo


router = APIRouter()
settings = get_settings()


@router.get("/health")
def health_check() -> dict:
    return {"status": "ok", "use_mocks": settings.use_mocks, "model": settings.openai_model}


@router.post("/briefing", response_model=FinalBriefing)
def create_briefing_route(payload: BriefingRequest) -> FinalBriefing:
    return create_briefing(
        user_input=payload.user_input,
        location=payload.location,
        date=payload.date,
        user_name=payload.user_name,
    )


@router.get("/admin/summary", response_model=AdminSummary)
def admin_summary() -> AdminSummary:
    return get_admin_summary()


@router.get("/presentation/demo", response_model=PresentationDemo)
def presentation_demo() -> PresentationDemo:
    return get_presentation_demo()
