from __future__ import annotations
from typing import List, Optional, Any
from pydantic import BaseModel, Field

# --- Common Models ---

class FeatureResponse(BaseModel):
    owner: str
    feature: str
    uses_mock: bool = True

# --- Weather (조수빈) ---

class WeatherBrief(FeatureResponse):
    location: str
    date: str
    summary: str
    temperature_c: float
    condition: str
    recommendation: str
    items: List[str]

# --- Calendar (김재희) ---

class CalendarEvent(BaseModel):
    title: str
    start: str
    end: str
    location: Optional[str] = None
    priority: Optional[str] = "medium"

class CalendarBrief(FeatureResponse):
    date: str
    summary: str
    events: List[CalendarEvent]
    conflicts: List[str]

# --- Slack (문이현) ---

class SlackChannelSummary(BaseModel):
    channel: str
    summary: str
    action_items: List[str] = []

class SlackMessage(BaseModel):
    user: str
    text: str
    ts: str

class SlackBrief(FeatureResponse):
    date: str
    summary: str
    channels: List[SlackChannelSummary]

class SlackSummaryRequest(BaseModel):
    channel_id: str = Field(min_length=1, description="Slack channel ID such as C0123456789")
    user_input: str = Field(default="최근 1일 대화 핵심만 5줄로 요약해줘")
    date: Optional[str] = Field(default=None, description="브리핑 기준 날짜")
    lookback_hours: int = Field(default=24, ge=1, le=168, description="몇 시간치 메시지를 읽을지")

class SlackSummaryResponse(FeatureResponse):
    date: str
    channel_id: str
    channel_name: str
    lookback_hours: int
    message_count: int
    summary: str
    summary_lines: List[str]
    messages: List[SlackMessage]
    model: str

# --- Admin (나정연) ---

class AdminMetric(BaseModel):
    feature: str
    owner: str
    token_estimate: int
    latency_ms: int
    status: str

class AdminNode(BaseModel):
    id: str
    label: str
    group: str

class AdminEdge(BaseModel):
    source: str
    target: str
    label: str

class AdminSummary(FeatureResponse):
    summary: str
    top_token_feature: str
    metrics: List[AdminMetric]
    flow_nodes: List[AdminNode]
    flow_edges: List[AdminEdge]

# --- Presentation (오승담) ---

class PresentationCard(BaseModel):
    title: str
    description: str
    talking_points: List[str]

class PresentationDemo(FeatureResponse):
    demo_title: str
    cards: List[PresentationCard]
    closing_message: str

# --- Orchestrator (배민규) ---

class BriefingRequest(BaseModel):
    user_input: str = Field(default="오늘 아침 브리핑 해줘")
    location: str = Field(default="Seoul")
    date: str = Field(default="2026-04-18")
    user_name: str = Field(default="Team Jarvis")

class FinalBriefing(BaseModel):
    headline: str
    generated_for: str
    user_input: str
    weather: WeatherBrief
    calendar: CalendarBrief
    slack: SlackBrief
    admin: AdminSummary
    presentation: PresentationDemo
    final_summary: str
