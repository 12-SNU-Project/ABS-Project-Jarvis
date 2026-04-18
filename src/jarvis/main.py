from __future__ import annotations

from fastapi import FastAPI

from jarvis.api.routes import router


app = FastAPI(
    title="Jarvis Multi-Agent API",
    version="0.1.0",
    description="Team-friendly Python skeleton for a mock-driven Jarvis assistant",
)
app.include_router(router)
