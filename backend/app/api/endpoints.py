from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.core.config import get_settings
from app.services.admin import get_admin_summary
from app.services.orchestrator import create_briefing
from app.services.slack_summary import summarize_slack_channel
from app.services.presentation import get_presentation_demo
from app.schemas.schemas import (
    AdminSummary,
    BriefingRequest,
    FinalBriefing,
    PresentationDemo,
    SlackSummaryRequest,
    SlackSummaryResponse,
)


router = APIRouter()


@router.get("/health")
def health_check() -> dict:
    settings = get_settings()
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


@router.post("/slack/summary", response_model=SlackSummaryResponse)
def slack_summary(payload: SlackSummaryRequest) -> SlackSummaryResponse:
    settings = get_settings()
    try:
        return summarize_slack_channel(
            channel_id=payload.channel_id,
            user_input=payload.user_input,
            date=payload.date or settings.default_date,
            lookback_hours=payload.lookback_hours,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
