from __future__ import annotations

from fastapi import FastAPI

from app.api.router import api_router


app = FastAPI(
    title="Jarvis Multi-Agent API",
    version="0.2.0",
    description="Professional MVP architecture for a multi-agent Jarvis assistant",
)
app.include_router(api_router)
