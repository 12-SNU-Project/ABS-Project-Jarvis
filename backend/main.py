from __future__ import annotations

from typing import Any

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.router import api_router
from app.core.errors import AppError
from app.schemas.schemas import ErrorContent, ErrorDetail, ErrorResponse


app = FastAPI(
    title="Jarvis Multi-Agent API",
    version="0.2.0",
    description="Professional MVP architecture for a multi-agent Jarvis assistant",
)
app.include_router(api_router)


def _error_response(
    *,
    code: str,
    message: str,
    status_code: int,
    details: list[dict[str, str | None]] | None = None,
) -> JSONResponse:
    error = ErrorResponse(
        error=ErrorContent(
            code=code,
            message=message,
            details=[ErrorDetail(**detail) for detail in (details or [])],
        )
    )
    return JSONResponse(status_code=status_code, content=error.model_dump())


@app.exception_handler(AppError)
def handle_app_error(_: Any, exc: AppError) -> JSONResponse:
    return _error_response(
        code=exc.code,
        message=exc.message,
        status_code=exc.status_code,
        details=exc.details,
    )


@app.exception_handler(RequestValidationError)
def handle_validation_error(_: Any, exc: RequestValidationError) -> JSONResponse:
    details = []
    for error in exc.errors():
        location = [str(item) for item in error.get("loc", []) if item != "body"]
        details.append(
            {
                "field": ".".join(location) if location else None,
                "message": error["msg"],
                "code": error["type"],
            }
        )
    return _error_response(
        code="validation_error",
        message="Request validation failed.",
        status_code=422,
        details=details,
    )


@app.exception_handler(StarletteHTTPException)
def handle_http_error(_: Any, exc: StarletteHTTPException) -> JSONResponse:
    if isinstance(exc.detail, dict) and "error" in exc.detail:
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    return _error_response(
        code="http_error",
        message=str(exc.detail),
        status_code=exc.status_code,
    )


@app.exception_handler(Exception)
def handle_unexpected_error(_: Any, exc: Exception) -> JSONResponse:
    return _error_response(
        code="internal_error",
        message="An unexpected server error occurred.",
        status_code=500,
        details=[],
    )
